{ config, lib, pkgs, ... }:
let
  cfg = config.cumserver.element-call;
  domain = "call.cum.army";
in
{
  options.cumserver.element-call = {
    enable = lib.mkEnableOption "Element Call with LiveKit backend";

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
      default = 50000;
      description = "LiveKit RTC UDP port range start";
    };

    livekitRtcUdpPortEnd = lib.mkOption {
      type = lib.types.port;
      default = 51000;
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
    ];

    services.livekit = {
      enable = true;
      keyFile = cfg.livekitKeyFile;
    };

    services.lk-jwt-service = {
      enable = true;
      livekitUrl = "wss://${domain}/livekit/sfu";
      keyFile = cfg.livekitKeyFile;
      port = cfg.jwtServicePort;
    };

    services.caddy.virtualHosts."${domain}" = {
      extraConfig = ''
        # Element Call frontend
        root * ${pkgs.element-call}

        route {
          # Config endpoint for Element Call standalone app
          respond /config.json `${builtins.toJSON {
            default_server_config = {
              "m.homeserver" = {
                base_url = "https://${config.cumserver.tuwunel.domain}";
                server_name = config.cumserver.tuwunel.mainDomain;
              };
            };
            livekit.livekit_service_url = "https://${domain}/livekit/jwt";
          }}` 200

          # lk-jwt-service endpoint (strips /livekit prefix)
          handle /livekit/sfu/get {
            uri strip_prefix /livekit
            reverse_proxy 127.0.0.1:${toString cfg.jwtServicePort}
          }

          # LiveKit SFU WebSocket endpoint
          handle_path /livekit/sfu* {
            reverse_proxy 127.0.0.1:${toString cfg.livekitPort}
          }

          # Serve Element Call SPA with fallback to index.html
          try_files {path} {path}/ /index.html
          file_server
        }
      '';
    };

    networking.firewall = {
      allowedTCPPorts = [ cfg.livekitRtcTcpPort ];
      allowedUDPPortRanges = [
        { from = cfg.livekitRtcUdpPortStart; to = cfg.livekitRtcUdpPortEnd; }
      ];
    };
  };
}
