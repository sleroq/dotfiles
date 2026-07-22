{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let
  cfg = config.sleroq.sing-box;
  settingsFormat = pkgs.formats.json { };
  hasSystemd = lib.hasAttrByPath [ "systemd" "services" ] options;
  hasLaunchd = lib.hasAttrByPath [ "launchd" "daemons" ] options;
  supportsDnsCache = lib.versionAtLeast cfg.package.version "1.14.0";

  routeRules = [
    {
      action = "sniff";
    }
    {
      type = "logical";
      mode = "or";
      rules = [
        { protocol = "dns"; }
        { port = 53; }
      ];
      action = "hijack-dns";
    }
  ] ++ [
    {
      process_name = cfg.directProcessNames;
      action = "route";
      outbound = "direct";
    }
  ] ++ [
    {
      domain_suffix = cfg.directDomains;
      action = "route";
      outbound = "direct";
    }
  ];

  tunInbound = {
    type = "tun";
    address = [
      "198.18.0.1/30"
      "fdfe:dcba:9876::1/126"
    ];
    auto_route = true;
    route_exclude_address = cfg.routeExcludeAddresses;
  } // lib.optionalAttrs hasSystemd {
    # sing-box 1.13 auto_redirect loses UDP replies on Linux even when the
    # selected outbound is direct (upstream issue #3560). auto_route still
    # captures TCP and UDP through the TUN without the broken nftables path.
    auto_redirect = false;
    strict_route = true;
  };

  defaultSettings = {
    log = {
      disabled = cfg.disableLogging;
      level = cfg.logLevel;
      timestamp = true;
    };

    dns = {
      servers = [
        # Proxy endpoint hostnames are resolved through this IP-address-based
        # resolver. Direct DoH uses its own direct dialer by default; sing-box
        # rejects detouring it through an otherwise empty direct outbound.
        # Port 443 is required here because auto_route reserves port 53 for
        # DNS hijacking, which would loop a UDP/TCP bootstrap resolver.
        # This bootstrap is the only normal-DNS exception; direct-domain and
        # direct-process rules deliberately use local-dns.
        {
          type = "https";
          tag = "bootstrap-dns";
          server = "1.1.1.1";
          server_port = 443;
          tls.server_name = "cloudflare-dns.com";
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

    # Runtime selector switching is intentionally disabled: the encrypted
    # selector's default remains the stable "proxy" target, with no exposed
    # Clash controller. The cache is retained only for sing-box state/cache.
    experimental = {
      cache_file = {
        enabled = true;
        path = "${workingDirectory}/clash.db";
      } // lib.optionalAttrs cfg.enablePersistentDnsCache {
        store_dns = true;
      };
    };
  };

  finalSettings = lib.recursiveUpdate defaultSettings cfg.settings;

  configTemplate = settingsFormat.generate "sing-box-config.json" (
    removeAttrs finalSettings [ "outbounds" ]
  );

  workingDirectory = "/var/lib/sing-box";
  configPath = "${workingDirectory}/config.json";
  logPath = "/var/log/sing-box.log";

  serviceRunner = pkgs.writeShellScript "sing-box-run" ''
    set -eu
    umask 077

    mkdir -p "${workingDirectory}" "$(dirname "${logPath}")"
    temporaryConfig="$(${pkgs.coreutils}/bin/mktemp "${workingDirectory}/config.json.tmp.XXXXXX")"
    trap '${pkgs.coreutils}/bin/rm -f "$temporaryConfig"' EXIT

    ${pkgs.jq}/bin/jq \
      --rawfile outbounds "${cfg.outboundsFile}" \
      '.outbounds = ($outbounds | fromjson)' \
      "${configTemplate}" > "$temporaryConfig"

    ${cfg.package}/bin/sing-box check -c "$temporaryConfig"
    ${pkgs.coreutils}/bin/mv -f "$temporaryConfig" "${configPath}"
    trap - EXIT

    exec ${cfg.package}/bin/sing-box run -c "${configPath}"
  '';
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
      type = lib.types.str;
      example = "/run/agenix/sing-box-outbounds.json";
      description = "Path to a JSON file containing the sing-box outbounds array.";
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
      description = ''
        sing-box log level. Use info/debug for routing diagnostics; warn suppresses per-connection process lookup logs.
      '';
    };

    disableLogging = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Disable sing-box logging after startup.";
    };

    directProcessNames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Exact, platform-dependent process names whose TCP, UDP, and DNS are routed directly.
        Avoid broad launchers such as wine and wineserver unless every application they run should bypass the proxy.
      '';
    };

    directDomains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "example.com" ];
      description = ''
        Domain suffixes whose DNS and connections are routed directly. A suffix without a leading dot
        matches both its apex and subdomains on current sing-box versions.
      '';
    };

    enablePersistentDnsCache = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable sing-box persistent DNS cache. Requires sing-box 1.14.0 or newer.
      '';
    };

    routeExcludeAddresses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "10.130.1.0/24"
        "10.130.100.0/24"
      ];
      description = ''
        Destination CIDRs excluded from sing-box TUN auto-routing.
        Use this for LAN or VPN-managed subnets that should stay under the system routing table.
        On sing-box 1.13, do not include ranges ending at the address-family maximum (such as
        255.255.255.255/32 or ff00::/8); sing-tun cannot encode them in an auto-redirect nftables interval set.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = settingsFormat.type;
      };
      default = { };
      description = ''
        The sing-box configuration, see https://sing-box.sagernet.org/configuration/ for documentation.

        These settings will be merged with sensible defaults. You can override any default setting
        by specifying it here.

        Example:
        ```nix
        outboundsFile = config.age.secrets.sing-box-outbounds.path;
        settings.log.level = "debug";
        ```
      '';
    };

  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = cfg.outboundsFile != "";
            message = "sleroq.sing-box.outboundsFile must be set.";
          }
          {
            assertion = !(cfg.settings ? outbounds);
            message = "Set sleroq.sing-box.outboundsFile instead of sleroq.sing-box.settings.outbounds.";
          }
          {
            assertion = cfg.enablePersistentDnsCache -> supportsDnsCache;
            message = "sleroq.sing-box.enablePersistentDnsCache requires sing-box 1.14.0 or newer; current package is ${cfg.package.version}.";
          }
        ];

        environment.systemPackages = [ cfg.package ];
      }

      (lib.optionalAttrs hasSystemd {
        systemd.services.sing-box = {
          description = "sing-box";
          wantedBy = [ "multi-user.target" ];
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          serviceConfig = {
            ExecStart = "${serviceRunner}";
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
    ]
  );
}
