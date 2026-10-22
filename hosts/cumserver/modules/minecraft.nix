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
  options.cumserver.minecraft = {
    cum.enable = lib.mkEnableOption "cum.army minecraft server";
    backup.enable = lib.mkEnableOption "backups" // {
      default = true;
    };
  };

  config = lib.mkMerge [
    {
      environment.etc."systemd/system.control/firewall.service".source = "${
        config.systemd.units."firewall.service".unit
      }/firewall.service";

      networking.firewall.allowedTCPPorts = lib.mapAttrsToList (
        _: server: server.serverProperties.server-port
      ) (lib.filterAttrs (_: server: server.enable) config.services.minecraft-servers.servers);

      services.minecraft-servers = {
        enable = true;
        eula = true;
        # Upstream opens RCON too; explicitly expose only enabled servers' game ports.
        openFirewall = false;

        servers = lib.mkMerge [
          (lib.mkIf cfg.cum.enable {
            cum = {
              enable = true;
              autoStart = true;
              jvmOpts = "-Xms2G -Xmx4G -XX:MaxDirectMemorySize=1G -XX:MaxMetaspaceSize=512M"; # -XX:+UseZGC
              package = pkgs.fabricServers.fabric-26_2.override {
                jre_headless = pkgs.jdk25_headless;
              };

              serverProperties = {
                difficulty = "normal";
                player-idle-timeout = 0;
                spawn-protection = 0;
                server-port = 25569;
                motd = "<3";
                online-mode = false;
                max-players = 10;
                white-list = true;
                enable-status = true;
                hide-online-players = true;
                allow-flight = true;
                sync-chunk-writes = false;
                enable-rcon = true;
                "rcon.password" = "localbackup";
                "rcon.port" = 25576;
              };
            };

            cum-creative = {
              enable = false;
              autoStart = true;
              jvmOpts = "-Xmx2G -XX:MaxDirectMemorySize=1G -XX:MaxMetaspaceSize=512M"; # -XX:+UseZGC
              package = pkgs.fabricServers.fabric-26_2.override {
                jre_headless = pkgs.jdk25_headless;
              };

              serverProperties = {
                difficulty = "normal";
                level-seed = -1694756061639681260;
                player-idle-timeout = 0;
                spawn-protection = 0;
                server-port = 25567;
                motd = "<3";
                online-mode = false;
                max-players = 10;
                white-list = true;
                enable-status = true;
                hide-online-players = true;
                allow-flight = true;
                sync-chunk-writes = false;
                enable-rcon = true;
                "rcon.password" = "localbackup";
                "rcon.port" = 25576;
              };
            };
          })
        ];
      };
    }
    (lib.mkIf cfg.cum.enable {
      systemd.services.minecraft-server-cum.path = [
        pkgs.git
        pkgs.git-lfs
      ];
    })

    (lib.mkIf (cfg.cum.enable && cfg.backup.enable) {
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
