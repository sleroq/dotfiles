{
  lib,
  pkgs,
  cfg,
  namedSources,
  hasSystemd,
  configTemplate,
  staticOutbounds,
  paths,
  directBypassMarkDecimal,
}:
let
  inherit (paths)
    workingDirectory
    configPath
    nodesPath
    sourceTagsPath
    manifestPath
    ;

  subscription = cfg.subscription;
  clashApi = "http://${subscription.apiAddress}";

  extraOutboundsArgument = lib.optionalString (cfg.extraOutboundsFile != null) ''
    --rawfile extraOutbounds "${cfg.extraOutboundsFile}" \
  '';
  extraOutboundsDefault = lib.optionalString (cfg.extraOutboundsFile == null) ''
    --argjson extraOutbounds '[]' \
  '';

  buildSubscriptionConfig = pkgs.writeShellScript "sing-box-build-config" ''
    set -eu

    nodesFile="$1"
    sourcesFile="$2"
    outputFile="$3"

    ${pkgs.jq}/bin/jq \
      --rawfile nodes "$nodesFile" \
      --slurpfile sourceTags "$sourcesFile" \
      ${extraOutboundsArgument}${extraOutboundsDefault}--slurpfile staticOutbounds "${staticOutbounds}" \
      --arg urlTestURL "${subscription.testURL}" \
      --arg urlTestInterval "${subscription.testInterval}" \
      --argjson urlTestTolerance ${toString subscription.tolerance} \
      --argjson linux ${if hasSystemd then "true" else "false"} \
      --argjson routingMark ${toString directBypassMarkDecimal} \
      '
        def parsed($value; $name):
          try ($value | fromjson) catch error("invalid " + $name + " JSON");
        def require_array($value; $name):
          if ($value | type) == "array" then $value else error($name + " must contain a JSON array") end;

        (require_array(parsed($nodes; "subscription outbounds"); "subscription outbounds")) as $nodes
        | (if ($extraOutbounds | type) == "string"
           then require_array(parsed($extraOutbounds; "extra outbounds"); "extra outbounds")
           else require_array($extraOutbounds; "extra outbounds")
           end) as $extra
        | ($staticOutbounds[0]) as $static
        | if ($nodes | length) == 0 then error("subscription contains no supported outbounds") else . end
        | ([$nodes[] | .tag] | if any(. == null or . == "") then error("every subscription outbound must have a tag") else . end) as $nodeTags
        | ([$extra[], $static[] | .tag] | map(select(. != null))) as $extraTags
        | ($nodeTags + $extraTags) as $leafTags
        | if (($leafTags | unique | length) != ($leafTags | length))
          then error("subscription and extra outbound tags must be unique") else . end
        | if any($leafTags[]; . == "direct" or . == "auto" or . == "proxy")
          then error("outbound tags direct, auto, and proxy are reserved") else . end
        | ($sourceTags[0]) as $bySource
        | ([$bySource[][]] | sort) as $mappedTags
        | if $mappedTags != ($nodeTags | sort)
          then error("source tag mapping does not match subscription outbounds") else . end
        | ([$bySource | to_entries[] | { type: "urltest", tag: ("auto-" + .key), outbounds: .value, url: $urlTestURL, interval: $urlTestInterval, tolerance: $urlTestTolerance }]) as $sourceGroups
        | ([$sourceGroups[].tag]) as $sourceGroupTags
        | if (($sourceGroupTags | unique | length) != ($sourceGroupTags | length))
          then error("duplicate source group tags") else . end
        | if any($sourceGroupTags[]; . == "direct" or . == "auto" or . == "proxy")
          then error("source name collides with a reserved group") else . end
        | if any($sourceGroupTags[]; . as $group | any($leafTags[]; . == $group))
          then error("source group tag collides with an outbound tag") else . end
        | .outbounds = (
            $nodes + $extra + $static + $sourceGroups + [
              {
                type: "urltest",
                tag: "auto",
                outbounds: ($nodeTags + $extraTags),
                url: $urlTestURL,
                interval: $urlTestInterval,
                tolerance: $urlTestTolerance
              },
              {
                type: "selector",
                tag: "proxy",
                outbounds: (["auto"] + $sourceGroupTags + $nodeTags + $extraTags),
                default: "auto"
              },
              { type: "direct", tag: "direct" }
            ]
            | if $linux
              then map(if .type == "direct" then . + { routing_mark: $routingMark } else . end)
              else .
              end
          )
      ' "${configTemplate}" > "$outputFile"

    ${cfg.package}/bin/sing-box check -c "$outputFile"
  '';

  restartService = if hasSystemd then
    ''${pkgs.systemd}/bin/systemctl restart sing-box.service''
  else
    ''/bin/launchctl kickstart -k system/org.nixos.sing-box'';

  fetchSources = lib.concatStrings (lib.imap0 (index: source: ''
    ${pkgs.jq}/bin/jq -nr --rawfile url ${lib.escapeShellArg source.urlFile} '
      ($url | sub("[\\r\\n]+$"; "")) as $url
      | if ($url == "" or ($url | test("[\\r\\n]")))
        then error("subscription source ${toString (index + 1)} URL file must contain exactly one URL")
        else "url = " + ($url | tojson)
        end
    ' > "$temporaryDirectory/curl.conf"

    ${pkgs.curl}/bin/curl \
      --fail \
      --silent \
      --show-error \
      --location \
      --config "$temporaryDirectory/curl.conf" \
      --output "$temporaryDirectory/subscription-${toString index}"

    ${subscription.package}/bin/sing-box-sub \
      "$temporaryDirectory/subscription-${toString index}" \
      --only-nodes \
      --prefix ${lib.escapeShellArg source.prefix} \
      --exclude-protocol "${subscription.excludeProtocols}" \
      --exclude-node-name "${subscription.excludeNodeNames}" \
      --out "$temporaryDirectory/nodes-${toString index}.json"
  '') namedSources);

  updateSubscription = pkgs.writeShellScript "sing-box-update" ''
    set -eu
    umask 077

    if [ "$(id -u)" -ne 0 ]; then
      echo "sb update must run as root (use sudo)" >&2
      exit 1
    fi

    mkdir -p "${workingDirectory}"
    lock="${workingDirectory}/update.lock"
    if ! mkdir "$lock" 2>/dev/null; then
      echo "another sing-box update is already running" >&2
      exit 1
    fi

    temporaryDirectory="$(${pkgs.coreutils}/bin/mktemp -d "${workingDirectory}/update.tmp.XXXXXX")"
    trap '${pkgs.coreutils}/bin/rm -rf "$temporaryDirectory"; rmdir "$lock"' EXIT

    ${fetchSources}

    ${pkgs.jq}/bin/jq -s 'add' "$temporaryDirectory"/nodes-*.json > "$temporaryDirectory/nodes.json"

    ${pkgs.jq}/bin/jq -s --argjson names ${lib.escapeShellArg (builtins.toJSON (map (s: s.name) namedSources))} '
      [range(0; length) as $index | { key: $names[$index], value: [.[$index][].tag] }] | from_entries
    ' "$temporaryDirectory"/nodes-*.json > "$temporaryDirectory/sources.json"

    ${buildSubscriptionConfig} "$temporaryDirectory/nodes.json" "$temporaryDirectory/sources.json" "$temporaryDirectory/config.json"
    ${pkgs.jq}/bin/jq -s \
      --slurpfile sourceTags "$temporaryDirectory/sources.json" \
      --arg updatedAt "$(${pkgs.coreutils}/bin/date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '
        ($sourceTags[0] | to_entries | map(.value[] as $tag | { key: $tag, value: .key }) | from_entries) as $tagSource
        | { updatedAt: $updatedAt, nodes: (add | map({ tag: .tag, type: .type, server: .server, source: ($tagSource[.tag] // "unknown") })) }
      ' \
      "$temporaryDirectory"/nodes-*.json > "$temporaryDirectory/manifest.json"

    ${pkgs.coreutils}/bin/install -m 0600 "$temporaryDirectory/nodes.json" "${nodesPath}.new"
    # Sources and manifest carry tags only, so sb list/status work without sudo.
    ${pkgs.coreutils}/bin/install -m 0644 "$temporaryDirectory/sources.json" "${sourceTagsPath}.new"
    # The manifest carries no credentials (tags, types, and server names
    # only) so that sb status works without sudo.
    ${pkgs.coreutils}/bin/install -m 0644 "$temporaryDirectory/manifest.json" "${manifestPath}.new"
    ${pkgs.coreutils}/bin/install -m 0600 "$temporaryDirectory/config.json" "${configPath}.new"
    ${pkgs.coreutils}/bin/mv -f "${nodesPath}.new" "${nodesPath}"
    ${pkgs.coreutils}/bin/mv -f "${sourceTagsPath}.new" "${sourceTagsPath}"
    ${pkgs.coreutils}/bin/mv -f "${manifestPath}.new" "${manifestPath}"
    ${pkgs.coreutils}/bin/mv -f "${configPath}.new" "${configPath}"

    ${restartService}
  '';

  sb = pkgs.writeShellApplication {
    name = "sb";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
      cfg.package
    ];
    text = ''
      api=${lib.escapeShellArg clashApi}
      config=${lib.escapeShellArg configPath}
      manifest=${lib.escapeShellArg manifestPath}

      usage() {
        cat <<'EOF'
Usage: sb update|list|test [GROUP]|use TAG|status|config [--raw]|check
EOF
      }

      command="''${1:-}"
      case "$command" in
        update)
          shift
          if [ "$#" -ne 0 ]; then usage >&2; exit 2; fi
          exec ${updateSubscription}
          ;;
        list)
          if [ -r "$manifest" ]; then
            curl --fail --silent --show-error "$api/proxies/proxy" |
              jq -r --slurpfile manifest "$manifest" '
                ($manifest[0].nodes // [] | map({ key: .tag, value: .source }) | from_entries) as $sourceOf
                | . as $group
                | .all[]
                | ((if . == $group.now then "* " else "  " end) + . + (if $sourceOf[.] then " [" + $sourceOf[.] + "]" else "" end))'
          else
            curl --fail --silent --show-error "$api/proxies/proxy" |
              jq -r '. as $group | .all[] | if . == $group.now then "* " + . else "  " + . end'
          fi
          ;;
        test)
          group="''${2:-auto}"
          case "$group" in
            *[!A-Za-z0-9_-]*|"") echo "invalid group: $group" >&2; exit 2 ;;
          esac
          curl --fail --silent --show-error \
            --get \
            --data-urlencode "url=${subscription.testURL}" \
            --data-urlencode "timeout=10000" \
            "$api/group/$group/delay" |
            jq -r 'to_entries | sort_by(.value)[] | "\(.value) ms\t\(.key)"'
          ;;
        use)
          if [ "$#" -ne 2 ]; then usage >&2; exit 2; fi
          jq -cn --arg name "$2" '{name: $name}' |
            curl --fail --silent --show-error \
              --request PUT \
              --header 'Content-Type: application/json' \
              --data-binary @- \
              "$api/proxies/proxy"
          printf 'selected %s\n' "$2"
          ;;
        status)
          if [ -r "$manifest" ]; then
            jq -r '"last update: " + .updatedAt, "nodes: " + (.nodes | length | tostring), (.nodes | group_by(.source)[] | "  " + .[0].source + ": " + (length | tostring))' "$manifest"
          else
            echo "subscription has not been updated"
          fi
          curl --fail --silent --show-error "$api/proxies/proxy" |
            jq -r '"selected: " + .now'
          ;;
        config)
          if [ ! -r "$config" ]; then echo "sb config requires root (use sudo)" >&2; exit 1; fi
          if [ "''${2:-}" = "--raw" ]; then
            if [ "$(id -u)" -ne 0 ]; then echo "sb config --raw requires root" >&2; exit 1; fi
            jq . "$config"
          else
            jq 'walk(if type == "object" then with_entries(if (.key | test("^(password|uuid|private_key|token|auth_str)$")) then .value = "<redacted>" else . end) else . end)' "$config"
          fi
          ;;
        check)
          if [ ! -r "$config" ]; then echo "sb check requires root (use sudo)" >&2; exit 1; fi
          exec sing-box check -c "$config"
          ;;
        ""|-h|--help|help)
          usage
          ;;
        *)
          usage >&2
          exit 2
          ;;
      esac
    '';
  };
in
{
  inherit buildSubscriptionConfig updateSubscription sb;
}
