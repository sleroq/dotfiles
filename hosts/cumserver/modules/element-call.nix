{ config, lib, pkgs, ... }:
let
  cfg = config.cumserver.element-call;
in
{
  options.cumserver.element-call = {
    enable = lib.mkEnableOption "Element Call with LiveKit backend";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "call.cum.army";
      description = "Domain name for Element Call";
    };

    livekitKeyFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to file containing LiveKit API key and secret in format 'key: secret'";
    };

    livekitPort = lib.mkOption {
      type = lib.types.port;
      default = 7880;
      description = "LiveKit HTTP/WebSocket port";
    };

    livekitRtcTcpPort = lib.mkOption {
      type = lib.types.port;
      default = 7881;
      description = "LiveKit RTC TCP port";
    };

    livekitRtcUdpPortStart = lib.mkOption {
      type = lib.types.port;
      default = 50100;
      description = "LiveKit RTC UDP port range start";
    };

    livekitRtcUdpPortEnd = lib.mkOption {
      type = lib.types.port;
      default = 50200;
      description = "LiveKit RTC UDP port range end";
    };

    jwtServicePort = lib.mkOption {
      type = lib.types.port;
      default = 8090;
      description = "lk-jwt-service port";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.caddy.enable;
        message = "Caddy must be enabled for Element Call to work";
      }
      {
        assertion = config.cumserver.tuwunel.enable;
        message = "Tuwunel must be enabled for Element Call to work";
      }
    ];

    services.livekit = {
      enable = true;
      keyFile = cfg.livekitKeyFile;
      settings = {
        port = cfg.livekitPort;
        rtc = {
          tcp_port = cfg.livekitRtcTcpPort;
          port_range_start = cfg.livekitRtcUdpPortStart;
          port_range_end = cfg.livekitRtcUdpPortEnd;
          turn_servers = lib.optionals config.cumserver.tuwunel.turn.enable [
            {
              host = config.cumserver.tuwunel.turn.domain;
              port = 5349;
              protocol = "tls";
              secret = config.cumserver.tuwunel.turn.secret;
            }
          ];
        };
      };
    };

    services.lk-jwt-service = {
      enable = true;
      livekitUrl = "wss://${cfg.domain}";
      keyFile = cfg.livekitKeyFile;
      port = cfg.jwtServicePort;
    };

    # Add LIVEKIT_FULL_ACCESS_HOMESERVERS to restrict room creation to our homeserver
    # The NixOS module doesn't expose this option, so we override the systemd service
    systemd.services.lk-jwt-service.environment.LIVEKIT_FULL_ACCESS_HOMESERVERS =
      config.cumserver.tuwunel.mainDomain;

    services.caddy.virtualHosts."${cfg.domain}" = {
      extraConfig = ''
        @jwt_service {
          path /sfu/get* /healthz*
        }

        @livekit_paths {
          path /rtc* /twirp*
        }

        @websocket {
          header Connection *Upgrade*
          header Upgrade websocket
        }

        handle @jwt_service {
          reverse_proxy 127.0.0.1:${toString cfg.jwtServicePort}
        }

        handle @livekit_paths {
          reverse_proxy 127.0.0.1:${toString cfg.livekitPort}
        }

        handle @websocket {
          reverse_proxy 127.0.0.1:${toString cfg.livekitPort}
        }

        handle /config.json {
          header Content-Type application/json
          respond `${
            builtins.toJSON {
              default_server_config."m.homeserver" = {
                base_url = "https://${config.cumserver.tuwunel.domain}";
                server_name = config.cumserver.tuwunel.mainDomain;
              };
            }
          }` 200
        }

        handle {
          root * ${pkgs.element-call}
          try_files {path} /index.html
          file_server
        }
      '';
    };

    networking.firewall = {
      allowedTCPPorts = [ cfg.livekitRtcTcpPort ];
      allowedUDPPortRanges = [
        {
          from = cfg.livekitRtcUdpPortStart;
          to = cfg.livekitRtcUdpPortEnd;
        }
      ];
    };
  };
}
