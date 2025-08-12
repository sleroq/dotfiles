{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.sleroq.sing-box;
  settingsFormat = pkgs.formats.json { };

  sing-box-beta = pkgs.sing-box.overrideAttrs (oldAttrs: rec {
    version = "1.12.0-beta.31";
    src = pkgs.fetchFromGitHub {
      owner = "SagerNet";
      repo = "sing-box";
      tag = "v${version}";
      hash = "sha256-WwwZePdEokhLIOMJLSZV5oIEuufr+1hPaiONYaz+Nzk=";
    };
    vendorHash = "sha256-t76QBdgTprVM5g6ytl0nG+daO6WEnI1Q5gA3bPMRR9Y=";
    tags = [
      "with_quic"
      "with_dhcp"
      "with_wireguard"
      "with_utls"
      "with_acme"
      "with_clash_api"
      "with_gvisor"
    ];
  });

  defaultSettings = {
    log = {
      level = "info";
      timestamp = true;
    };
    dns = {
      servers = [
        {
          tag = "google";
          type = "tls";
          server = "8.8.8.8";
        }
      ];
    };
    route = {
      default_domain_resolver = "google";
      rules = [
        {
          action = "sniff";
        }
        {
          protocol = "dns";
          action = "hijack-dns";
        }
      ];
      auto_detect_interface = true;
    };
    inbounds = [
      {
        type = "mixed";
        tag = "mixed-in";
        listen = "127.0.0.1";
        listen_port = 2080;
        sniff = true;
        sniff_override_destination = true;
      }
    ];
    experimental = {
      cache_file = {
        enabled = true;
        path = "clash.db";
        store_rdrc = true;
      };
      clash_api = {
        default_mode = "Enhanced";
      };
    };
  };

in
{
  options.sleroq.sing-box = {
    enable = lib.mkEnableOption "sing-box universal proxy platform";

    package = lib.mkOption {
      type = lib.types.package;
      default = sing-box-beta;
      description = "The sing-box package to use.";
    };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = settingsFormat.type;
      };
      default = {};
      description = ''
        The sing-box configuration, see https://sing-box.sagernet.org/configuration/ for documentation.

        These settings will be merged with sensible defaults. You can override any default setting
        by specifying it here.

        Options containing secret data should be set to an attribute set
        containing the attribute `_secret` - a string pointing to a file
        containing the value the option should be set to.

        Example:
        ```nix
        settings = {
          log.level = "debug";
          outbounds = { _secret = "/path/to/secret/outbounds.json"; quote = false; };
        };
        ```
      '';
    };

    useTunMode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to use TUN mode for transparent proxying.
        If true, sing-box will run as root and create a TUN interface.
        If false, will use mixed mode (HTTP/SOCKS proxy).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.sing-box = {
      enable = true;
      inherit (cfg) package;
      settings = lib.mkMerge [
        defaultSettings
        
        cfg.settings
        
        (lib.mkIf cfg.useTunMode {
          inbounds = [
            {
              address = [
                "172.19.0.1/30"
                "fdfe:dcba:9876::1/126"
              ];
              route_address = [
                "0.0.0.0/1"
                "128.0.0.0/1"
                "::/1"
                "8000::/1"
              ];
              type = "tun";
              auto_route = true;
              auto_redirect = true;
              strict_route = true;
            }
          ];
        })
      ];
    };

    environment.systemPackages = [
      cfg.package
    ];

    systemd.services.sing-box.serviceConfig = lib.mkMerge [
      (lib.mkIf (!cfg.useTunMode) {
        DynamicUser = true;
        User = "sing-box";
        Group = "sing-box";
      })
      (lib.mkIf cfg.useTunMode {
        User = "root";
        Group = "root";
        AmbientCapabilities = [ "CAP_NET_ADMIN" "CAP_NET_RAW" ];
        CapabilityBoundingSet = [ "CAP_NET_ADMIN" "CAP_NET_RAW" ];
      })
    ];
  };
}
