{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.cumserver.minecraft;
in
{
  options.cumserver.minecraft.backup.enable = lib.mkEnableOption "backups" // {
    default = true;
  };

  config = lib.mkMerge [
    {
      environment.etc."systemd/system.control/firewall.service".source = "${
        config.systemd.units."firewall.service".unit
      }/firewall.service";

      networking.firewall.allowedTCPPorts = lib.mapAttrsToList (
        _: server: server.serverProperties.server-port
      ) (lib.filterAttrs (_: server: server.enable) config.services.minecraft-servers.servers);
    }
    (lib.mkIf config.services.cumcraft.enable {
      age.secrets.cumcraftEasyAuthPassword = {
        file = ../secrets/cumcraftEasyAuthPassword;
        owner = "minecraft";
      };
      services.cumcraft.easyAuth.passwordFile = config.age.secrets.cumcraftEasyAuthPassword.path;
      systemd.services.minecraft-server-cum.restartTriggers = [
        config.age.secrets.cumcraftEasyAuthPassword.file
      ];

      services.minecraft-servers.servers.cum.serverProperties = {
        enable-rcon = true;
        "rcon.password" = "localbackup";
        "rcon.port" = 25576;
      };
    })
    (lib.mkIf (config.services.cumcraft.enable && cfg.backup.enable) {
      age.secrets.resticMinecraftPassword = {
        owner = "minecraft";
        group = "minecraft";
        file = ../secrets/resticMinecraftPassword;
      };

      age.secrets.resticMinecraftRestEnv.file = ../secrets/resticMinecraftRestEnv;

      services.restic.backups.minecraft = {
        user = "minecraft";
        repository = "rest:http://div.capybara-menkent.ts.net:8040/minecraft/";
        passwordFile = config.age.secrets.resticMinecraftPassword.path;
        environmentFile = config.age.secrets.resticMinecraftRestEnv.path;
        initialize = true;
        paths = [ "/srv/minecraft/cum" ];
        exclude = [
          "logs"
          "crash-reports"
          "hs_err_pid*.log"
          "**/DistantHorizons.sqlite"
        ];
        # The append-only endpoint cannot prune; div owns retention.
        timerConfig = {
          OnCalendar = "03:30";
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
        backupPrepareCommand = ''
          set +e
          if systemctl is-active --quiet minecraft-server-cum.service; then
            ${pkgs.mcrcon}/bin/mcrcon -H 127.0.0.1 -P 25576 -p localbackup "save-off" || true
            ${pkgs.mcrcon}/bin/mcrcon -H 127.0.0.1 -P 25576 -p localbackup "save-all flush" || true
          fi
        '';
        backupCleanupCommand = ''
          set +e
          if systemctl is-active --quiet minecraft-server-cum.service; then
            ${pkgs.mcrcon}/bin/mcrcon -H 127.0.0.1 -P 25576 -p localbackup "save-on" || true
          fi
        '';
      };
    })
  ];
}
