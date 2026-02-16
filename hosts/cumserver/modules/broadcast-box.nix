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

    backup.enable = lib.mkEnableOption "backups" // {
      default = true;
    };

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

    stateDirectory = lib.mkOption {
      type = lib.types.str;
      default = "broadcast-box";
      description = "State directory name under /var/lib/private for Broadcast Box";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.services.caddy.enable;
          message = "broadcast-box requires Caddy to be enabled for reverse proxy. Set services.caddy.enable = true";
        }
      ];

      services.redis.servers.broadcast-box = {
        enable = true;
        bind = "127.0.0.1";
        port = 6379;
        appendOnly = true;
        save = [
          [
            60
            1
          ]
          [
            300
            10
          ]
        ];
      };

      services.broadcast-box = {
        enable = true;
        web = {
          host = "127.0.0.1";
          port = cfg.port;
        };
        settings = {
          REDIS_URL = "redis://localhost:6379/0";
          UDP_MUX_PORT = cfg.udpPort;
          NETWORK_TYPES = "udp4";
          NAT_1_TO_1_IP = (builtins.head config.networking.interfaces.ens3.ipv4.addresses).address;
          NETWORK_TEST_ON_START = "false";
          LOGGING_DIRECTORY = "/var/lib/private/${cfg.stateDirectory}/logs";
          STREAM_PROFILE_PATH = "/var/lib/private/${cfg.stateDirectory}/profiles";
          DISABLE_STATUS = false;
          DISABLE_FRONTEND = true;
        };
      };

      systemd.services.broadcast-box.serviceConfig = {
        WorkingDirectory = "/var/lib/private/${cfg.stateDirectory}";
        StateDirectory = cfg.stateDirectory;
        StateDirectoryMode = "0700";
        RuntimeDirectory = "broadcast-box";
        RuntimeDirectoryMode = "0750";
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
    })

    (lib.mkIf (cfg.enable && cfg.backup.enable) {
      services.restic.backups.broadcast-box-redis = {
        user = "root";
        repository = "s3:https://b9b008414ac92325dff304821d2a0a2c.eu.r2.cloudflarestorage.com/bots-backups";
        passwordFile = config.age.secrets.resticBackupsPassword.path;
        environmentFile = config.age.secrets.resticS3Keys.path;
        initialize = true;
        paths = [ "/var/lib/redis-broadcast-box" ];
        pruneOpts = [
          "--keep-daily 1"
          "--keep-weekly 5"
          "--keep-monthly 12"
        ];
        timerConfig = {
          OnCalendar = "04:40";
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
        backupPrepareCommand = ''
          set +e
          if systemctl is-active --quiet redis-broadcast-box.service; then
            ${config.services.redis.package}/bin/redis-cli -s /run/redis-broadcast-box/redis.sock SAVE || true
          fi
        '';
      };
    })
  ];
}
