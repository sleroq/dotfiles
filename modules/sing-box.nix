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
  logPath = "/var/log/sing-box.log";

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
  ]
  ++ lib.optional (cfg.directProcessNames != [ ]) {
    process_name = cfg.directProcessNames;
    action = "route";
    outbound = "direct";
  }
  ++ lib.optional (cfg.directDomains != [ ]) {
    domain_suffix = cfg.directDomains;
    action = "route";
    outbound = "direct";
  };

  tunInbound = {
    type = "tun";
    address = [ "198.18.0.1/30" ] ++ lib.optional cfg.enableIPv6 "fdfe:dcba:9876::1/126";
    auto_route = true;
    route_exclude_address = cfg.routeExcludeAddresses;
  }
  // lib.optionalAttrs hasSystemd {
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

      rules =
        lib.optional (cfg.directProcessNames != [ ]) {
          process_name = cfg.directProcessNames;
          action = "route";
          server = "local-dns";
          strategy = "ipv4_only";
        }
        ++ lib.optional (cfg.directDomains != [ ]) {
          domain_suffix = cfg.directDomains;
          action = "route";
          server = "local-dns";
          strategy = "ipv4_only";
        };

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
      }
      // lib.optionalAttrs cfg.enablePersistentDnsCache {
        store_dns = true;
      };
    }
    // lib.optionalAttrs subscription.enable {
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

  serviceRunner = pkgs.writeShellScript "sing-box-run" ''
    set -eu
    umask 077
    # The public manifest is readable without sudo; secrets remain mode 0600.
    ${pkgs.coreutils}/bin/install -d -m 0755 "${workingDirectory}"
    mkdir -p "$(dirname "${logPath}")"
    ${cli.sb}/bin/sb prepare
    exec ${cfg.package}/bin/sing-box run -c "${configPath}"
  '';

  # Sources with default names filled in (src<N>). All downstream logic
  # uses this so per-source groups and the manifest stay consistent.
  namedSources = lib.imap0 (
    index: source:
    source // { name = if source.name != "" then source.name else "src${toString index}"; }
  ) subscription.sources;

  cli = import ./sing-box-cli.nix {
    inherit
      lib
      pkgs
      cfg
      namedSources
      hasSystemd
      configTemplate
      staticOutbounds
      workingDirectory
      directBypassMarkDecimal
      ;
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

    cliPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.sb;
      description = "The sb subscription management CLI package.";
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
            description = ''
              Deprecated single subscription URL file. Use sources instead.
            '';
          };

          sources = lib.mkOption {
            type = lib.types.listOf (
              lib.types.submodule {
                options = {
                  name = lib.mkOption {
                    type = lib.types.str;
                    default = "";
                    description = ''
                      Short source name. Shown by sb and used for the auto-<name>
                      group. Defaults to src<N>. Must match [A-Za-z0-9_-]+.
                    '';
                  };
                  urlFile = lib.mkOption {
                    type = lib.types.str;
                    description = "Root-only file containing exactly one subscription URL.";
                  };
                  prefix = lib.mkOption {
                    type = lib.types.str;
                    default = "";
                    description = "Prefix added to converted outbound tags from this source.";
                  };
                  enable = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = "Whether this subscription participates. CLI overrides persist until reset and take precedence over this default.";
                  };
                  autoSelect = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = "Include this subscription in automatic selection; false leaves nodes manually selectable.";
                  };
                  includeTags = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [ ];
                    description = "Go regular expressions limiting automatic selection by node tag. Empty means all tags.";
                  };
                  excludeTags = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [ ];
                    description = "Go regular expressions excluding node tags from automatic selection. Exclusions win.";
                  };
                  includeServers = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [ ];
                    description = "Go regular expressions limiting automatic selection by server hostname or address.";
                  };
                  excludeServers = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [ ];
                    description = "Go regular expressions excluding server hostnames or addresses from automatic selection.";
                  };
                };
              }
            );
            default = [ ];
            example = [
              { urlFile = "/run/agenix/sing-box-subscription-main"; }
              {
                urlFile = "/run/agenix/sing-box-subscription-cw";
                prefix = "cw-";
              }
            ];
            description = ''
              Subscription sources. Every source is fetched, converted, and
              merged into one node set. Tag collisions across sources fail the
              update loudly instead of shadowing nodes.
            '';
          };

          stores = lib.mkOption {
            type = lib.types.listOf (
              lib.types.submodule {
                options = {
                  name = lib.mkOption {
                    type = lib.types.str;
                    description = "Unique store name used by sb subscription add --store.";
                  };
                  path = lib.mkOption {
                    type = lib.types.str;
                    description = "Runtime JSON subscription store path; may reference an agenix file or an editable symlink.";
                  };
                  writable = lib.mkOption {
                    type = lib.types.bool;
                    default = false;
                    description = "Whether sb may edit this store. Leave false for Nix/agenix-managed files.";
                  };
                };
              }
            );
            default = [
              {
                name = "local";
                path = "${workingDirectory}/subscriptions.json";
                writable = true;
              }
            ];
            description = ''
              Additional subscription stores, merged with sources by unique ID.
              Store files contain {"subscriptions": [{"id": "main", "url_file": "/run/agenix/url"}]}.
              URLs must stay in runtime files, never in Nix store values.
              Read-only sources can be enabled/disabled and filtered through private CLI overrides.
            '';
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

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = subscription.enable -> subscription.urlFile == null;
            message = "sleroq.sing-box.subscription.urlFile is deprecated; use subscription.sources instead.";
          }
          {
            assertion = subscription.enable -> (subscription.sources != [ ] || subscription.stores != [ ]);
            message = "Configure subscription.sources or subscription.stores when subscription management is enabled.";
          }
          {
            assertion = subscription.enable -> lib.all (source: source.urlFile != "") namedSources;
            message = "Every sleroq.sing-box.subscription.sources entry must set urlFile.";
          }
          {
            assertion =
              subscription.enable
              -> lib.all (source: builtins.match "[A-Za-z0-9_-]+" source.name != null) namedSources;
            message = "Every sleroq.sing-box.subscription.sources name must match [A-Za-z0-9_-]+; it is used in group tags and API paths.";
          }
          {
            assertion =
              subscription.enable
              -> lib.unique (map (source: source.name) namedSources) == map (source: source.name) namedSources;
            message = "sleroq.sing-box.subscription.sources names must be unique.";
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
            assertion =
              subscription.enable
              -> (
                lib.attrByPath [ "experimental" "clash_api" "external_controller" ] null finalSettings
                == subscription.apiAddress
              );
            message = "Set subscription.apiAddress instead of overriding settings.experimental.clash_api.external_controller; sb and sing-box must use the same loopback endpoint.";
          }
          {
            assertion = cfg.enablePersistentDnsCache -> supportsDnsCache;
            message = "sleroq.sing-box.enablePersistentDnsCache requires sing-box 1.14.0 or newer; current package is ${cfg.package.version}.";
          }
        ];

        environment.systemPackages = [
          cfg.package
          cli.sb
        ];
        environment.etc."sb/config.json".source = cli.settings;
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
            ExecStart = cli.updateSubscription;
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
            ProgramArguments = [ "${cli.updateSubscription}" ];
            StartInterval = subscription.updateInterval;
            StandardOutPath = logPath;
            StandardErrorPath = logPath;
          };
        };
      })
    ]
  );
}
