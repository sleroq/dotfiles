{
  pkgs,
  inputs',
  config,
  lib,
  ...
}:
let
  cfg = config.cumserver.caddy;
in
{
  options.cumserver.caddy.enable = lib.mkEnableOption "Caddy";

  # TODO: Solve {"level":"warn","ts":1756318480.6253746,"logger":"caddyfile","msg":"Unnecessary header_up X-Forwarded-For: the reverse proxy's default behavior is to pass headers to the upstream"}

  config = lib.mkIf cfg.enable {
    services.caddy = {
      enable = true;
      package = pkgs.caddy.withPlugins {
        plugins = [ "github.com/mholt/caddy-l4@v0.1.2" ];
        hash = "sha256-UIv8PxtJMlX7qClnPazFsSSl7G1BzsTT8VjrMIfB46Q=";
      };
      email = "admin@sleroq.link";
      # Layer 4 routing lets TrustTunnel and Hysteria2 share public UDP/443.
      globalConfig = ''
        layer4 {
          udp/:443 {
            @trusttunnel quic sni ${config.cumserver.trusttunnel.domain}
            route @trusttunnel {
              proxy udp/127.0.0.1:${toString config.cumserver.trusttunnel.port}
            }

            route {
              proxy udp/127.0.0.1:${toString config.cumserver.remnawave.node.clientUdpPort}
            }
          }
        }

        servers {
          protocols h1 h2
          listener_wrappers {
            layer4 {
              @trusttunnel tls sni ${config.cumserver.trusttunnel.domain}
              route @trusttunnel {
                proxy tcp/127.0.0.1:${toString config.cumserver.trusttunnel.port}
              }
            }
            tls
          }
        }
      '';
      virtualHosts = {
        "cum.army" = {
          serverAliases = [ "www.cum.army" ];
          extraConfig = ''
            root * ${inputs'.cum-army.packages.default}
            encode zstd gzip

            # Shortcut for fauna pic to avoid /u/
            redir /fauna /u/fauna-final.png 308
            file_server

            ${lib.optionalString config.cumserver.zipline.enable ''
              handle_errors {
                @notfound expression {http.error.status_code} == 404
                handle @notfound {
                  reverse_proxy localhost:${toString config.cumserver.zipline.port}
                }
              }''}
          ''; # TODO: This can probably be moved to zipline server and simplified
        };

        "edge.cum.army" = {
          extraConfig = ''
            root * ${inputs'.cum-army.packages.default}
            encode zstd gzip
            file_server
          '';
        };

        "div.cum.army" = {
          extraConfig = ''
            root * ${inputs'.cum-army.packages.default}
            encode zstd gzip
            file_server
          '';
        };
      };
    };

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];
  };
}
