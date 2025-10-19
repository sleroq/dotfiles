{ config, lib, ... }:
let
  cfg = config.cumserver.marzban;
in
{
  options.cumserver.marzban = {
    enable = lib.mkEnableOption "Marzban proxy management panel";

    backup.enable = lib.mkEnableOption "backups" // { default = true; };

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/gozargah/marzban:v0.8.4";
      # default = "ghcr.io/gozargah/marzban:v1.0.0-beta-3";
      description = "Docker image to use for Marzban";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "uwu.sleroq.link";
      description = "Domain name for Marzban";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "Internal port for Marzban";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/marzban";
      description = "Data directory for Marzban";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Environment file containing Marzban configuration";
    };

    extraOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "--network=host" ];
      description = "Additional options to pass to the container";
    };

    metricsEnvironmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Environment file containing Marzban metrics exporter configuration";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.virtualisation.oci-containers.backend != null;
          message = "OCI containers backend must be configured for Marzban to work";
        }
        {
          assertion = config.services.caddy.enable;
          message = "Caddy has to be enabled for Marzban to work";
        }
      ];

      virtualisation.oci-containers.containers = {
        marzban = {
          autoStart = true;
          inherit (cfg) image;
          environmentFiles = lib.optional (cfg.environmentFile != null) cfg.environmentFile;
          environment = {
            UVICORN_HOST = "127.0.0.1";
            UVICORN_PORT = toString cfg.port;
            XRAY_JSON = "/var/lib/marzban/xray_config.json";
            SQLALCHEMY_DATABASE_URL = "sqlite:////var/lib/marzban/db.sqlite3";
            # SQLALCHEMY_DATABASE_URL = "sqlite+aiosqlite:////var/lib/marzban/db.sqlite3";
          };
          inherit (cfg) extraOptions;
          volumes = [
            "${cfg.dataDir}:/var/lib/marzban"
          ];
        };
      } // lib.optionalAttrs (config.cumserver.monitoring.enable && cfg.metricsEnvironmentFile != null) {
        marzban-exporter = {
          autoStart = true;
          image = "kutovoys/marzban-exporter:v0.2.3";
          environmentFiles = [ cfg.metricsEnvironmentFile ];
          ports = [ "127.0.0.1:9091:9090" ];
          dependsOn = [ "marzban" ];
        };
      };

      services.caddy.virtualHosts.${cfg.domain} = {
        extraConfig = ''
          reverse_proxy 127.0.0.1:${toString cfg.port}
          
          header {
            X-Content-Type-Options nosniff
            X-Frame-Options SAMEORIGIN
            X-XSS-Protection "1; mode=block"
            X-Real-IP {remote_addr}
            X-Forwarded-For {remote_addr}
            X-Forwarded-Host {host}
          }
          
          encode zstd gzip
        '';
      };

      systemd.tmpfiles.rules = [
        "d ${cfg.dataDir} 0755 root root -"
      ];

      networking.firewall.allowedTCPPorts = [
        2080 # vless
        8081 # vmess
      ];

      services.prometheus.scrapeConfigs = lib.mkIf (config.cumserver.monitoring.enable && cfg.metricsEnvironmentFile != null) [
        {
          job_name = "marzban";
          static_configs = [{ targets = [ "127.0.0.1:9091" ]; }];
          scrape_interval = "30s";
        }
      ];
    })

    (lib.mkIf (cfg.enable && cfg.backup.enable) {
      services.restic.backups.marzban = {
        user = "root";
        repository = "s3:https://b9b008414ac92325dff304821d2a0a2c.eu.r2.cloudflarestorage.com/bots-backups";
        passwordFile = config.age.secrets.resticBackupsPassword.path;
        environmentFile = config.age.secrets.resticS3Keys.path;
        initialize = true;
        paths = [ cfg.dataDir ];
        pruneOpts = [
          "--keep-daily 1"
          "--keep-weekly 5"
          "--keep-monthly 12"
        ];
        timerConfig = {
          OnCalendar = "04:35";
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
      };
    })
  ];
}
