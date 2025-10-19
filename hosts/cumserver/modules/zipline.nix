{ config, lib, ... }:

let
  cfg = config.cumserver.zipline;
in
{
  options.cumserver.zipline = {
    enable = lib.mkEnableOption "Zipline file sharing server";

    backup.enable = lib.mkEnableOption "backups" // { default = true; };
    
    domain = lib.mkOption {
      type = lib.types.str;
      default = "share.cum.army";
      description = "Domain name for Zipline";
    };
    
    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Internal port for Zipline";
    };

    environmentFile = lib.mkOption {
      type = lib.types.path;
      description = "Environment file for Zipline";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.services.caddy.enable;
          message = "Caddy has to be enabled for Zipline to work";
        }
      ];

      services.zipline = {
        enable = true;
        
        environmentFiles = [ cfg.environmentFile ];
        
        settings = {
          CORE_PORT = cfg.port;
        };
        
        database.createLocally = true;
      };

      services.caddy.virtualHosts = {
        ${cfg.domain} = {
          extraConfig = ''
            reverse_proxy localhost:${toString cfg.port}
            encode zstd gzip
            
            header {
              X-Content-Type-Options nosniff
              X-Frame-Options SAMEORIGIN
              X-XSS-Protection "1; mode=block"
            }
          '';
        };
      };
    })

    (lib.mkIf (cfg.enable && cfg.backup.enable) {
      services.restic.backups.zipline = {
        user = "root";
        repository = "s3:https://b9b008414ac92325dff304821d2a0a2c.eu.r2.cloudflarestorage.com/bots-backups";
        passwordFile = config.age.secrets.resticBackupsPassword.path;
        environmentFile = config.age.secrets.resticS3Keys.path;
        initialize = true;

        backupPrepareCommand = ''
          set -euo pipefail
          mkdir -p /var/lib/private/zipline/backup
          /run/wrappers/bin/su -s /bin/sh postgres -c "${config.services.postgresql.package}/bin/pg_dump --dbname='postgresql:///zipline?host=/run/postgresql' --no-owner --no-privileges" | /run/current-system/sw/bin/tee /var/lib/private/zipline/backup/zipline.sql > /dev/null
        '';

        backupCleanupCommand = ''
          rm -f /var/lib/private/zipline/backup/zipline.sql
        '';

        paths = [ "/var/lib/private/zipline" ];
        pruneOpts = [ "--keep-weekly 2" "--keep-monthly 4" ];
        timerConfig = {
          OnCalendar = "weekly";
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
      };
    })
  ];
} 
