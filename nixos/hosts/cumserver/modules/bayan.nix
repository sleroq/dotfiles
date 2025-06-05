{ config, lib, pkgs, inputs, secrets, ... }:

with lib;

let
  cfg = config.services.bayan;
in
{
  options.services.bayan = {
    enable = mkEnableOption "bayan telegram bot";

    user = mkOption {
      type = types.str;
      default = "bayan";
      description = "User to run the bayan bot service as";
    };

    group = mkOption {
      type = types.str;
      default = "bayan";
      description = "Group to run the bayan bot service as";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/bayan";
      description = "Directory where bayan will store its SQLite database";
    };
  };

  config = mkIf cfg.enable {
    age.secrets.bayanEnv = {
      owner = cfg.user;
      group = cfg.group;
      file = ../secrets/bayanEnv;
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
    };

    users.groups.${cfg.group} = {};

    systemd.services.bayan = {
      description = "Bayan Telegram Bot";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        Restart = "always";
        RestartSec = "10s";
        WorkingDirectory = cfg.dataDir;
        EnvironmentFile = config.age.secrets.bayanEnv.path;
        
        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
      };

      script = ''
        exec ${inputs.bayan.packages.${pkgs.system}.default}/bin/bayan
      '';
    };

    # Ensure the data directory has correct permissions
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} - -"
    ];
  };
}
