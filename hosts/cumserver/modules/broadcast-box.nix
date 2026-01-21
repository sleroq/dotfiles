{ inputs', config, lib, ... }:
let
  cfg = config.cumserver.broadcast-box;
in
{
  options.cumserver.broadcast-box = {
    enable = lib.mkEnableOption "Broadcast Box WebRTC streaming server";

    domain = lib.mkOption {
      type = lib.types.str;
      description = "Domain name for Broadcast Box";
      example = "broadcast.example.com";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Internal port for Broadcast Box HTTP server";
    };

    udpPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "UDP port for WebRTC traffic";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "seaduboi/broadcast-box:latest";
      description = "Docker image to use for Broadcast Box";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to environment file containing sensitive configuration";
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Additional environment variables";
      example = {
        DISABLE_STATUS = "false";
        NETWORK_TEST_ON_START = "false";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.virtualisation.oci-containers.backend != null;
        message = "OCI containers backend must be configured for Marzban to work";
      }
      {
        assertion = config.services.caddy.enable;
        message = "broadcast-box requires Caddy to be enabled for reverse proxy. Set services.caddy.enable = true";
      }
    ];

    # Open UDP port in firewall for WebRTC traffic
    networking.firewall = {
      allowedUDPPorts = [ cfg.udpPort ];
    };

    virtualisation.oci-containers.containers.broadcast-box = {
      inherit (cfg) image;
      autoStart = true;

      ports = [
        "127.0.0.1:${toString cfg.port}:8080"
        "0.0.0.0:${toString cfg.udpPort}:${toString cfg.udpPort}/udp"
      ];

      environment = {
        HTTP_ADDRESS = ":8080";
        ENABLE_HTTP_REDIRECT = "false";
        UDP_MUX_PORT = toString cfg.udpPort;
        NETWORK_TYPES = "udp4";
        NAT_1_TO_1_IP = (builtins.head config.networking.interfaces.ens3.ipv4.addresses).address;
        NETWORK_TEST_ON_START = "false";
        DISABLE_STATUS = "true";
        DISABLE_FRONTEND = "1";
      } // cfg.extraEnvironment;

      environmentFiles = lib.optional (cfg.environmentFile != null) cfg.environmentFile;

      extraOptions = [
        "--hostname=broadcast-box"
        "--sysctl=net.ipv6.conf.all.disable_ipv6=1"
        "--sysctl=net.ipv6.conf.default.disable_ipv6=1"
      ];
    };

    services.caddy.virtualHosts.${cfg.domain} = {
      extraConfig = ''
        @websockets {
          header Connection *Upgrade*
          header Upgrade websocket
        }

        # Force directive ordering so that headers are applied to both
        # proxied requests and the response.
        route {
          header {
            X-Content-Type-Options nosniff
            X-Frame-Options DENY
            X-XSS-Protection "1; mode=block"
            Referrer-Policy strict-origin-when-cross-origin
          }

          # API and WebSockets go to the container
          handle_path /api/* {
            reverse_proxy @websockets 127.0.0.1:${toString cfg.port}
            reverse_proxy 127.0.0.1:${toString cfg.port}
          }

          # Everything else serves the static frontend from web-cum-army
          handle {
            root * ${inputs'.web-cum-army.packages.default}
            try_files {path} /index.html
            file_server
            encode zstd gzip
          }
        }
      '';
    };
  };
}
