{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let
  cfg = config.sleroq.sing-box;
  subscription = cfg.subscription;
  settingsFormat = pkgs.formats.json { };
  hasSystemd = lib.hasAttrByPath [ "systemd" "services" ] options;
  hasLaunchd = lib.hasAttrByPath [ "launchd" "daemons" ] options;
  supportsDnsCache = lib.versionAtLeast cfg.package.version "1.14.0";
  directBypassMark = "0x5342";
  directBypassMarkDecimal = 21314;

  workingDirectory = "/var/lib/sing-box";
  configPath = "${workingDirectory}/config.json";
  nodesPath = "${workingDirectory}/subscription-outbounds.json";
  manifestPath = "${workingDirectory}/subscription.json";
  logPath = "/var/log/sing-box.log";
  clashApi = "http://${subscription.apiAddress}";

  routeRules = [
    { action = "sniff"; }
    {
      type = "logical";
      mode = "or";
      rules = [
        { protocol = "dns"; }
        { port = 53; }
      ];
      action = "hijack-dns";
    }
    {
      process_name = cfg.directProcessNames;
      action = "route";
      outbound = "direct";
    }
    {
      domain_suffix = cfg.directDomains;
      action = "route";
      outbound = "direct";
    }
  ];

  tunInbound = {
    type = "tun";
    address = [ "198.18.0.1/30" ] ++ lib.optional cfg.enableIPv6 "fdfe:dcba:9876::1/126";
    auto_route = true;
    route_exclude_address = cfg.routeExcludeAddresses;
  } // lib.optionalAttrs hasSystemd {
    # The default mixed stack uses the Linux system stack for TCP. This host's
    # firewall drops that TUN-side TCP before sing-box can accept it, while the
    # gVisor stack handles both TCP and UDP in userspace.
    stack = "gvisor";
    # Keep the known-good path until the sing-box 1.13 UDP auto_redirect issue
    # is retested independently on the currently pinned version.
    auto_redirect = false;
    strict_route = false;
  };

  defaultSettings = {
    log = {
      disabled = cfg.disableLogging;
      level = cfg.logLevel;
      timestamp = true;
    };

    dns = {
      servers = [
        {
          type = "udp";
          tag = "bootstrap-dns";
          server = "1.1.1.1";
          server_port = 53;
        }
        {
          type = "https";
          tag = "remote-dns";
          server = "1.1.1.1";
          server_port = 443;
          tls.server_name = "cloudflare-dns.com";
          detour = "proxy";
        }
        {
          type = "local";
          tag = "local-dns";
        }
      ];

      rules = [
        {
          process_name = cfg.directProcessNames;
          action = "route";
          server = "local-dns";
          strategy = "ipv4_only";
        }
        {
          domain_suffix = cfg.directDomains;
          action = "route";
          server = "local-dns";
          strategy = "ipv4_only";
        }
      ];

      strategy = "ipv4_only";
      final = "remote-dns";
    };

    inbounds = [ tunInbound ];

    route = {
      rules = routeRules;
      final = "proxy";
      auto_detect_interface = true;
      default_domain_resolver = "bootstrap-dns";
    };

    experimental = {
      cache_file = {
        enabled = true;
        path = "${workingDirectory}/clash.db";
      } // lib.optionalAttrs cfg.enablePersistentDnsCache {
        store_dns = true;
      };
    } // lib.optionalAttrs subscription.enable {
      clash_api.external_controller = subscription.apiAddress;
    };
  };

  finalSettings = lib.recursiveUpdate defaultSettings cfg.settings;
  configTemplate = settingsFormat.generate "sing-box-config.json" (
    removeAttrs finalSettings [ "outbounds" ]
  );
  staticOutbounds = settingsFormat.generate "sing-box-static-outbounds.json" cfg.staticOutbounds;

  directRuleSetup = pkgs.writeShellScript "sing-box-direct-rule-setup" ''
    ${pkgs.iproute2}/bin/ip rule del priority 8999 fwmark ${directBypassMark} lookup main 2>/dev/null || true
    ${pkgs.iproute2}/bin/ip rule add priority 8999 fwmark ${directBypassMark} lookup main
  '';

  directRuleCleanup = pkgs.writeShellScript "sing-box-direct-rule-cleanup" ''
    ${pkgs.iproute2}/bin/ip rule del priority 8999 fwmark ${directBypassMark} lookup main 2>/dev/null || true
  '';

  installLegacyOutbounds = if hasSystemd then
    ''.outbounds = (($outbounds | fromjson) | map(if .type == "direct" then . + { routing_mark: ${toString directBypassMarkDecimal} } else . end))''
  else
    ''.outbounds = ($outbounds | fromjson)'';

  legacyRunner = pkgs.writeShellScript "sing-box-run" ''
    set -eu
    umask 077

    mkdir -p "${workingDirectory}" "$(dirname "${logPath}")"
    temporaryConfig="$(${pkgs.coreutils}/bin/mktemp "${workingDirectory}/config.json.tmp.XXXXXX")"
    trap '${pkgs.coreutils}/bin/rm -f "$temporaryConfig"' EXIT

    ${pkgs.jq}/bin/jq \
      --rawfile outbounds "${cfg.outboundsFile}" \
      '${installLegacyOutbounds}' \
      "${configTemplate}" > "$temporaryConfig"

    ${cfg.package}/bin/sing-box check -c "$temporaryConfig"
    ${pkgs.coreutils}/bin/mv -f "$temporaryConfig" "${configPath}"
    trap - EXIT

    exec ${cfg.package}/bin/sing-box run -c "${configPath}"
  '';

  extraOutboundsArgument = lib.optionalString (cfg.extraOutboundsFile != null) ''
    --rawfile extraOutbounds "${cfg.extraOutboundsFile}" \
  '';
  extraOutboundsDefault = lib.optionalString (cfg.extraOutboundsFile == null) ''
    --argjson extraOutbounds '[]' \
  '';

  buildSubscriptionConfig = pkgs.writeShellScript "sing-box-build-config" ''
    set -eu

    nodesFile="$1"
    outputFile="$2"

    ${pkgs.jq}/bin/jq \
      --rawfile nodes "$nodesFile" \
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
        | .outbounds = (
            $nodes + $extra + $static + [
              {
                type: "urltest",
                tag: "auto",
                outbounds: $nodeTags,
                url: $urlTestURL,
                interval: $urlTestInterval,
                tolerance: $urlTestTolerance
              },
              {
                type: "selector",
                tag: "proxy",
                outbounds: (["auto"] + $nodeTags + $extraTags),
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

  subscriptionRunner = pkgs.writeShellScript "sing-box-run" ''
    set -eu
    umask 077

    mkdir -p "${workingDirectory}" "$(dirname "${logPath}")"
    if [ ! -s "${nodesPath}" ]; then
      echo "No cached subscription. Run: sudo sb update" >&2
      exit 1
    fi

    temporaryConfig="$(${pkgs.coreutils}/bin/mktemp "${workingDirectory}/config.json.tmp.XXXXXX")"
    trap '${pkgs.coreutils}/bin/rm -f "$temporaryConfig"' EXIT
    ${buildSubscriptionConfig} "${nodesPath}" "$temporaryConfig"
    ${pkgs.coreutils}/bin/mv -f "$temporaryConfig" "${configPath}"
    trap - EXIT

    exec ${cfg.package}/bin/sing-box run -c "${configPath}"
  '';

  serviceRunner = if subscription.enable then subscriptionRunner else legacyRunner;

  restartService = if hasSystemd then
    ''${pkgs.systemd}/bin/systemctl restart sing-box.service''
  else
    ''/bin/launchctl kickstart -k system/org.nixos.sing-box'';

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

    ${pkgs.jq}/bin/jq -Rn --rawfile url "${subscription.urlFile}" '
      ($url | sub("[\\r\\n]+$"; "")) as $url
      | if ($url == "" or ($url | test("[\\r\\n]")))
        then error("subscription URL file must contain exactly one URL")
        else "url = " + ($url | tojson)
        end
    ' > "$temporaryDirectory/curl.conf"

    ${pkgs.curl}/bin/curl \
      --fail \
      --silent \
      --show-error \
      --location \
      --config "$temporaryDirectory/curl.conf" \
      --output "$temporaryDirectory/subscription"

    ${subscription.package}/bin/sing-box-sub \
      "$temporaryDirectory/subscription" \
      --only-nodes \
      --prefix "sub-" \
      --exclude-protocol "${subscription.excludeProtocols}" \
      --exclude-node-name "${subscription.excludeNodeNames}" \
      --out "$temporaryDirectory/nodes.json"

    ${buildSubscriptionConfig} "$temporaryDirectory/nodes.json" "$temporaryDirectory/config.json"
    ${pkgs.jq}/bin/jq \
      --arg updatedAt "$(${pkgs.coreutils}/bin/date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{ updatedAt: $updatedAt, nodes: map({ tag, type, server }) }' \
      "$temporaryDirectory/nodes.json" > "$temporaryDirectory/manifest.json"

    ${pkgs.coreutils}/bin/install -m 0600 "$temporaryDirectory/nodes.json" "${nodesPath}.new"
    ${pkgs.coreutils}/bin/install -m 0600 "$temporaryDirectory/manifest.json" "${manifestPath}.new"
    ${pkgs.coreutils}/bin/install -m 0600 "$temporaryDirectory/config.json" "${configPath}.new"
    ${pkgs.coreutils}/bin/mv -f "${nodesPath}.new" "${nodesPath}"
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
Usage: sb update|list|test|use TAG|status|config [--raw]|check
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
          curl --fail --silent --show-error "$api/proxies/proxy" |
            jq -r '. as $group | .all[] | if . == $group.now then "* " + . else "  " + . end'
          ;;
        test)
          curl --fail --silent --show-error \
            --get \
            --data-urlencode "url=${subscription.testURL}" \
            --data-urlencode "timeout=10000" \
            "$api/group/auto/delay" |
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
            jq -r '"last update: " + .updatedAt + "\nnodes: " + (.nodes | length | tostring)' "$manifest"
          else
            echo "subscription has not been updated"
          fi
          curl --fail --silent --show-error "$api/proxies/proxy" |
            jq -r '"selected: " + .now'
          ;;
        config)
          if [ "''${2:-}" = "--raw" ]; then
            if [ "$(id -u)" -ne 0 ]; then echo "sb config --raw requires root" >&2; exit 1; fi
            jq . "$config"
          else
            jq 'walk(if type == "object" then with_entries(if (.key | test("^(password|uuid|private_key|token|auth_str)$")) then .value = "<redacted>" else . end) else . end)' "$config"
          fi
          ;;
        check)
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
  options.sleroq.sing-box = {
    enable = lib.mkEnableOption "sing-box universal proxy platform";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.sing-box;
      description = "The sing-box package to use.";
    };

    outboundsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/agenix/sing-box-outbounds.json";
      description = "Legacy path to a complete JSON outbounds array.";
    };

    staticOutbounds = lib.mkOption {
      type = lib.types.listOf settingsFormat.type;
      default = [ ];
      description = "Non-secret manually maintained outbounds added to subscription nodes.";
    };

    extraOutboundsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional root-only JSON array of extra outbounds added to subscription nodes.";
    };

    subscription = lib.mkOption {
      default = { };
      description = "Subscription update, latency test, and selector configuration.";
      type = lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "managed sing-box subscription";

          package = lib.mkOption {
            type = lib.types.package;
            default = pkgs.sing-box-subscribe-cli;
            description = "Subscription converter package.";
          };

          urlFile = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Root-only file containing exactly one subscription URL.";
          };

          updateInterval = lib.mkOption {
            type = lib.types.ints.positive;
            default = 86400;
            description = "Automatic subscription update interval in seconds.";
          };

          apiAddress = lib.mkOption {
            type = lib.types.str;
            default = "127.0.0.1:9090";
            description = "Loopback Clash API address used by sb.";
          };

          testURL = lib.mkOption {
            type = lib.types.str;
            default = "https://www.gstatic.com/generate_204";
            description = "URL used for outbound latency tests.";
          };

          testInterval = lib.mkOption {
            type = lib.types.str;
            default = "5m";
            description = "sing-box URLTest interval.";
          };

          tolerance = lib.mkOption {
            type = lib.types.ints.unsigned;
            default = 50;
            description = "URLTest switching tolerance in milliseconds.";
          };

          excludeProtocols = lib.mkOption {
            type = lib.types.str;
            default = "ssr";
            description = "Comma-separated protocols ignored by the converter.";
          };

          excludeNodeNames = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Comma- or pipe-separated node name substrings ignored by the converter.";
          };
        };
      };
    };

    logLevel = lib.mkOption {
      type = lib.types.enum [
        "trace"
        "debug"
        "info"
        "warn"
        "error"
        "fatal"
        "panic"
      ];
      default = "warn";
      description = "sing-box log level.";
    };

    disableLogging = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Disable sing-box logging after startup.";
    };

    directProcessNames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Exact platform-dependent process names routed directly.";
    };

    directDomains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "example.com" ];
      description = "Domain suffixes whose DNS and connections are routed directly.";
    };

    enablePersistentDnsCache = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable sing-box persistent DNS cache. Requires sing-box 1.14.0 or newer.";
    };

    enableIPv6 = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Route IPv6 traffic through the TUN.";
    };

    routeExcludeAddresses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Destination CIDRs excluded from sing-box TUN auto-routing.";
    };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = settingsFormat.type;
      };
      default = { };
      description = ''
        Native sing-box configuration recursively merged over module defaults.
        This remains the unrestricted escape hatch for complex routing and DNS.
      '';
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [
        {
          assertion = subscription.enable -> subscription.urlFile != null;
          message = "sleroq.sing-box.subscription.urlFile must be set when subscription management is enabled.";
        }
        {
          assertion = subscription.enable -> cfg.outboundsFile == null;
          message = "Use staticOutbounds/extraOutboundsFile instead of outboundsFile with subscription management.";
        }
        {
          assertion = (!subscription.enable) -> cfg.outboundsFile != null;
          message = "Set sleroq.sing-box.outboundsFile or enable subscription management.";
        }
        {
          assertion = !(cfg.settings ? outbounds);
          message = "Use staticOutbounds or extraOutboundsFile instead of settings.outbounds.";
        }
        {
          assertion = subscription.enable -> lib.hasPrefix "127.0.0.1:" subscription.apiAddress;
          message = "The unauthenticated sing-box Clash API must listen on 127.0.0.1.";
        }
        {
          assertion = cfg.enablePersistentDnsCache -> supportsDnsCache;
          message = "sleroq.sing-box.enablePersistentDnsCache requires sing-box 1.14.0 or newer; current package is ${cfg.package.version}.";
        }
      ];

      environment.systemPackages = [ cfg.package ] ++ lib.optional subscription.enable sb;
    }

    (lib.optionalAttrs hasSystemd {
      systemd.services.sing-box = {
        description = "sing-box";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          ExecStartPre = directRuleSetup;
          ExecStart = serviceRunner;
          ExecStopPost = directRuleCleanup;
          Restart = "on-failure";
          User = "root";
          Group = "root";
          StateDirectory = "sing-box";
          AmbientCapabilities = [
            "CAP_DAC_READ_SEARCH"
            "CAP_NET_ADMIN"
            "CAP_NET_RAW"
            "CAP_SYS_PTRACE"
          ];
          CapabilityBoundingSet = [
            "CAP_DAC_READ_SEARCH"
            "CAP_NET_ADMIN"
            "CAP_NET_RAW"
            "CAP_SYS_PTRACE"
          ];
        };
      };
    })

    (lib.optionalAttrs hasSystemd {
      systemd.services.sing-box-update = lib.mkIf subscription.enable {
        description = "Update sing-box subscription";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = updateSubscription;
        };
      };
      systemd.timers.sing-box-update = lib.mkIf subscription.enable {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "5m";
          OnUnitActiveSec = "${toString subscription.updateInterval}s";
          Unit = "sing-box-update.service";
        };
      };
    })

    (lib.optionalAttrs hasLaunchd {
      launchd.daemons.sing-box = {
        serviceConfig = {
          ProgramArguments = [ "${serviceRunner}" ];
          RunAtLoad = true;
          KeepAlive = true;
          StandardOutPath = logPath;
          StandardErrorPath = logPath;
        };
      };
    })

    (lib.optionalAttrs hasLaunchd {
      launchd.daemons.sing-box-update = lib.mkIf subscription.enable {
        serviceConfig = {
          ProgramArguments = [ "${updateSubscription}" ];
          StartInterval = subscription.updateInterval;
          StandardOutPath = logPath;
          StandardErrorPath = logPath;
        };
      };
    })
  ]);
}
