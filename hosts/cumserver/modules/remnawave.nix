{ config, lib, ... }:
let
  cfg = config.cumserver.remnawave;
in
{
  options.cumserver.remnawave = {
    enable = lib.mkEnableOption "Remnawave proxy management panel";

    backup.enable = lib.mkEnableOption "backups" // { default = true; };

    image = lib.mkOption {
      type = lib.types.str;
      default = "remnawave/backend:2";
      description = "Docker image to use for Remnawave backend";
    };

    postgresImage = lib.mkOption {
      type = lib.types.str;
      default = "postgres:17.6";
      description = "Docker image to use for Remnawave PostgreSQL";
    };

    redisImage = lib.mkOption {
      type = lib.types.str;
      default = "valkey/valkey:8.1-alpine";
      description = "Docker image to use for Remnawave Redis/Valkey";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "uwu.sleroq.link";
      description = "Domain name for Remnawave panel";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Internal port for Remnawave panel";
    };

    metricsPort = lib.mkOption {
      type = lib.types.port;
      default = 3001;
      description = "Internal port for Remnawave metrics endpoint";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/remnawave";
      description = "Data directory for Remnawave state";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Environment file containing Remnawave backend and PostgreSQL variables";
    };

    extraOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "--network=host" ];
      description = "Additional options to pass to Remnawave containers";
    };

    subscriptionPage = {
      enable = lib.mkEnableOption "Remnawave subscription page";

      image = lib.mkOption {
        type = lib.types.str;
        default = "remnawave/subscription-page:latest";
        description = "Docker image to use for Remnawave subscription page";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 3010;
        description = "Internal port for Remnawave subscription page";
      };

      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional domain for Remnawave subscription page";
      };

      environmentFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Optional env file for subscription page (legacy Marzban compatibility variables)";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.virtualisation.oci-containers.backend != null;
          message = "OCI containers backend must be configured for Remnawave to work";
        }
        {
          assertion = config.services.caddy.enable;
          message = "Caddy has to be enabled for Remnawave to work";
        }
        {
          assertion = cfg.environmentFile != null;
          message = "cumserver.remnawave.environmentFile must be set and contain required Remnawave env vars";
        }
        {
          assertion = cfg.subscriptionPage.enable || cfg.subscriptionPage.domain == null;
          message = "cumserver.remnawave.subscriptionPage.domain requires cumserver.remnawave.subscriptionPage.enable = true";
        }
      ];

      virtualisation.oci-containers.containers = {
        remnawave-db = {
          autoStart = true;
          image = cfg.postgresImage;
          environmentFiles = [ cfg.environmentFile ];
          extraOptions = cfg.extraOptions;
          volumes = [
            "${cfg.dataDir}/postgres:/var/lib/postgresql/data"
          ];
        };

        remnawave-redis = {
          autoStart = true;
          image = cfg.redisImage;
          cmd = [
            "valkey-server"
            "--save"
            ""
            "--appendonly"
            "no"
            "--maxmemory-policy"
            "noeviction"
            "--loglevel"
            "warning"
          ];
          extraOptions = cfg.extraOptions;
        };

        remnawave = {
          autoStart = true;
          image = cfg.image;
          dependsOn = [ "remnawave-db" "remnawave-redis" ];
          environmentFiles = [ cfg.environmentFile ];
          environment = {
            APP_PORT = toString cfg.port;
            METRICS_PORT = toString cfg.metricsPort;
          };
          extraOptions = cfg.extraOptions;
        };
      } // lib.optionalAttrs cfg.subscriptionPage.enable {
        remnawave-subscription-page = {
          autoStart = true;
          image = cfg.subscriptionPage.image;
          dependsOn = [ "remnawave" ];
          environmentFiles = lib.optional (cfg.subscriptionPage.environmentFile != null) cfg.subscriptionPage.environmentFile;
          environment = {
            APP_PORT = toString cfg.subscriptionPage.port;
            REMNAWAVE_PANEL_URL = "http://127.0.0.1:${toString cfg.port}";
          };
          extraOptions = cfg.extraOptions;
        };
      };

      services.caddy.virtualHosts = {
        ${cfg.domain} = {
          extraConfig = ''
            reverse_proxy 127.0.0.1:${toString cfg.port}
            encode zstd gzip

            header {
              X-Content-Type-Options nosniff
              X-Frame-Options SAMEORIGIN
              X-XSS-Protection "1; mode=block"
              X-Real-IP {remote_addr}
              X-Forwarded-For {remote_addr}
              X-Forwarded-Host {host}
            }
          '';
        };
      } // lib.optionalAttrs (cfg.subscriptionPage.enable && cfg.subscriptionPage.domain != null) {
        ${cfg.subscriptionPage.domain} = {
          extraConfig = ''
            reverse_proxy 127.0.0.1:${toString cfg.subscriptionPage.port}
            encode zstd gzip

            header {
              X-Content-Type-Options nosniff
              X-Frame-Options SAMEORIGIN
              X-XSS-Protection "1; mode=block"
            }
          '';
        };
      };

      systemd.tmpfiles.rules = [
        "d ${cfg.dataDir} 0755 root root -"
        "d ${cfg.dataDir}/postgres 0755 root root -"
      ];
    })

    (lib.mkIf (cfg.enable && cfg.backup.enable) {
      services.restic.backups.remnawave = {
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
