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
    });

    config = let
      cfg = config.services.${name};
    in mkIf cfg.enable {
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
    };
  };
} 
