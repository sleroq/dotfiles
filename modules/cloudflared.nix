{ config, lib, ... }:

let
  cfg = config.sleroq.cloudflared;
in
{
  options.sleroq.cloudflared = {
    enable = lib.mkEnableOption "host-wide Cloudflared transport configuration";

    protocol = lib.mkOption {
      type = lib.types.enum [
        "auto"
        "http2"
        "quic"
      ];
      default = "auto";
      description = "Transport used by Cloudflared to connect to the Cloudflare edge.";
    };

    tunnels = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            id = lib.mkOption {
              type = lib.types.str;
              description = "Cloudflare Tunnel UUID.";
            };

            credentialsFile = lib.mkOption {
              type = lib.types.path;
              description = "Path to the tunnel-scoped Cloudflare credentials JSON file.";
            };

            routes = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              default = { };
              description = "Hostnames and their local origin services.";
            };

            default = lib.mkOption {
              type = lib.types.str;
              default = "http_status:404";
              description = "Catch-all service when no route matches.";
            };

            restartTriggers = lib.mkOption {
              type = lib.types.listOf lib.types.path;
              default = [ ];
              description = "Files whose changes restart this tunnel.";
            };
          };
        }
      );
      default = { };
      description = "Locally managed Cloudflare Tunnels on this host.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.cloudflared = {
      enable = true;
      tunnels = lib.mapAttrs' (
        _: tunnel:
        lib.nameValuePair tunnel.id {
          inherit (tunnel) credentialsFile default;
          ingress = tunnel.routes;
        }
      ) cfg.tunnels;
    };

    systemd.services = lib.mapAttrs' (
      _: tunnel:
      lib.nameValuePair "cloudflared-tunnel-${tunnel.id}" {
        inherit (tunnel) restartTriggers;
        environment.TUNNEL_TRANSPORT_PROTOCOL = cfg.protocol;
      }
    ) cfg.tunnels;
  };
}
