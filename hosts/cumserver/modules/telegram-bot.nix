{ config, lib, ... }:

with lib;

{
  mkTelegramBot = { name, package, secretFile, dataDir ? null }: {
    options.services.${name} = {
      enable = mkEnableOption "${name} telegram bot";

      user = mkOption {
        type = types.str;
        default = name;
        description = "User to run the ${name} bot service as";
      };

      group = mkOption {
        type = types.str;
        default = name;
        description = "Group to run the ${name} bot service as";
      };
    } // (optionalAttrs (dataDir != null) {
      dataDir = mkOption {
        type = types.path;
        default = dataDir;
        description = "Directory where ${name} will store its data";
      };

      backup.enable = lib.mkEnableOption "backups" // { default = true; };
    });

    config = let
      cfg = config.services.${name};
    in mkMerge [
      (mkIf cfg.enable {
        age.secrets."${name}Env" = {
          owner = cfg.user;
          inherit (cfg) group;
          file = secretFile;
        };

        users.users.${cfg.user} = {
          isSystemUser = true;
          inherit (cfg) group;
        } // (optionalAttrs (dataDir != null) {
          home = cfg.dataDir;
          createHome = true;
        });

        users.groups.${cfg.group} = {};

        systemd.services.${name} = {
          description = "${toUpper (substring 0 1 name)}${substring 1 (stringLength name) name} Telegram Bot";
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];

          serviceConfig = {
            Type = "simple";
            User = cfg.user;
            Group = cfg.group;
            Restart = "always";
            RestartSec = "10s";
            EnvironmentFile = config.age.secrets."${name}Env".path;
            
            # Security hardening
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateDevices = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;
          } // (optionalAttrs (dataDir != null) {
            WorkingDirectory = cfg.dataDir;
            ReadWritePaths = [ cfg.dataDir ];
          });

          script = ''
            exec ${package}/bin/${name}
          '';
        };
      })

      (mkIf (cfg.enable && cfg?backup && cfg?dataDir && cfg.backup.enable) {
        users.groups.restic-backups.members = [ cfg.user ];
        users.groups.restic-s3-backups.members = [ cfg.user ];

        services.restic.backups.${name} = {
          user = cfg.user;
          repository = "s3:https://b9b008414ac92325dff304821d2a0a2c.eu.r2.cloudflarestorage.com/bots-backups";
          passwordFile = config.age.secrets.resticBackupsPassword.path;
          environmentFile = config.age.secrets.resticS3Keys.path;
          initialize = true;
          paths = [ cfg.dataDir ];
          exclude = [ "**/*.log" ];
          pruneOpts = [
            "--keep-daily 7"
            "--keep-weekly 5"
            "--keep-monthly 12"
          ];
          timerConfig = {
            OnCalendar = "03:35";
            Persistent = true;
            RandomizedDelaySec = "1h";
          };
        };
      })
    ];
  };
} 
