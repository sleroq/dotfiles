{ config, lib, pkgs, inputs, secrets, ... }:

with lib;

let
  cfg = config.services.kopoka;
in
{
  options.services.kopoka = {
    enable = mkEnableOption "kopoka telegram bot";

    user = mkOption {
      type = types.str;
      default = "kopoka";
      description = "User to run the kopoka bot service as";
    };

    group = mkOption {
      type = types.str;
      default = "kopoka";
      description = "Group to run the kopoka bot service as";
    };
  };

  config = mkIf cfg.enable {
    age.secrets.kopokaEnv = {
      owner = cfg.user;
      group = cfg.group;
      file = ../secrets/kopokaEnv;
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
    };

    users.groups.${cfg.group} = {};

    systemd.services.kopoka = {
      description = "Kopoka Telegram Bot";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        Restart = "always";
        RestartSec = "10s";
        EnvironmentFile = config.age.secrets.kopokaEnv.path;
        
        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
      };

      script = ''
        exec ${inputs.kopoka.packages.${pkgs.system}.default}/bin/kopoka
      '';
    };
  };
}
