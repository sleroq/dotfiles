{
  inputs',
  config,
  lib,
  ...
}:
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
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.caddy.enable;
        message = "broadcast-box requires Caddy to be enabled for reverse proxy. Set services.caddy.enable = true";
      }
    ];

    services.broadcast-box = {
      enable = true;
      web = {
        host = "127.0.0.1";
        port = cfg.port;
      };
      settings = {
        UDP_MUX_PORT = cfg.udpPort;
        NETWORK_TYPES = "udp4";
        NAT_1_TO_1_IP = (builtins.head config.networking.interfaces.ens3.ipv4.addresses).address;
        NETWORK_TEST_ON_START = "false";
        DISABLE_STATUS = false;
        DISABLE_FRONTEND = true;
      };
    };

    networking.firewall = {
      allowedUDPPorts = [ cfg.udpPort ];
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
          handle /api/* {
            reverse_proxy @websockets 127.0.0.1:${toString cfg.port}
            reverse_proxy 127.0.0.1:${toString cfg.port}
          }

          # Everything else serves the static frontend from web-cum-army
          handle {
            root * ${
              inputs'.web-cum-army.packages.default.override {
                siteTitle = "Broadcast Box";
                apiPath = "https://${cfg.domain}/api";
              }
            }

            @index {
              file
              path / /index.html
            }
            header @index Cache-Control "no-cache, no-store, must-revalidate"

            @static {
              file
              path *.js *.css *.png *.jpg *.jpeg *.gif *.svg *.woff *.woff2
            }
            header @static Cache-Control "public, max-age=31536000, immutable"

            try_files {path} /index.html
            file_server
            encode zstd gzip
          }
        }
      '';
    };
  };
}
