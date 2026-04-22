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

  directDomains = [
    ".ru"
    ".local"
    ".nelocal"
    ".frg"
    ".frankrg.com"
  ];

  tunInbound = {
    type = "tun";
    address = [ "198.18.0.1/30" ];
    auto_route = true;
    route_exclude_address = cfg.routeExcludeAddresses;
  };

  defaultSettings = {
    log = {
      level = "info";
      timestamp = true;
    };

    dns = {
      servers = [
        {
          type = "tls";
          tag = "remote-dns";
          server = "1.1.1.1";
          server_port = 853;
        }
        {
          type = "local";
          tag = "local-dns";
        }
      ];

      rules = [
        {
          domain_suffix = directDomains;
          server = "local-dns";
          strategy = "ipv4_only";
        }
      ];

      strategy = "ipv4_only";
      final = "remote-dns";
    };

    inbounds = [ tunInbound ];

    route = {
      rules = [
        {
          action = "sniff";
        }
        {
          ip_version = 6;
          action = "reject";
        }
        {
          network = [ "udp" ];
          port = [ 443 ];
          action = "reject";
        }
        {
          network = [ "udp" ];
          action = "route";
          outbound = "direct";
        }
        {
          protocol = "dns";
          action = "hijack-dns";
        }
        {
          ip_is_private = true;
          action = "route";
          outbound = "direct";
        }
        {
          domain_suffix = directDomains;
          action = "route";
          outbound = "direct";
        }
      ];

      final = "proxy";
      auto_detect_interface = true;
      default_domain_resolver = "local-dns";
    };

    experimental = {
      cache_file = {
        enabled = true;
        path = "${workingDirectory}/clash.db";
      };
      clash_api = {
        default_mode = "Enhanced";
      };
    };
  };

  finalSettings = lib.recursiveUpdate defaultSettings cfg.settings;

  configTemplate = settingsFormat.generate "sing-box-config.json" (
    removeAttrs finalSettings [ "outbounds" ]
  );

  configPath = "/etc/sing-box/config.json";
  workingDirectory = "/var/lib/sing-box";
  logPath = "/var/log/sing-box.log";

  serviceRunner = pkgs.writeShellScript "sing-box-run" ''
    set -eu

    mkdir -p "/etc/sing-box" "${workingDirectory}" "$(dirname "${logPath}")"

    ${pkgs.jq}/bin/jq \
      --rawfile outbounds "${cfg.outboundsFile}" \
      '.outbounds = ($outbounds | fromjson)' \
      "${configTemplate}" > "${configPath}"

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
            AmbientCapabilities = [
              "CAP_NET_ADMIN"
              "CAP_NET_RAW"
            ];
            CapabilityBoundingSet = [
              "CAP_NET_ADMIN"
              "CAP_NET_RAW"
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
