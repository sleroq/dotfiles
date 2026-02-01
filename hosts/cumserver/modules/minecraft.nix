{ pkgs, config, lib, ... }:

let
  cfg = config.cumserver.minecraft;
in
{
  options.cumserver.minecraft = {
      cum.enable = lib.mkEnableOption "cum.army minecraft server";
      forever-chu.enable = lib.mkEnableOption "Forever Chu minecraft server";
      backup.enable = lib.mkEnableOption "backups" // { default = true; };
  };

  config = lib.mkMerge [
    {
      services.minecraft-servers = {
        enable = true;
        eula = true;
        openFirewall = true;

        servers = lib.mkMerge [
          (lib.mkIf cfg.cum.enable {
            cum = {
              enable = true;
              autoStart = true;
              jvmOpts = "-Xms3G -Xmx4G";
              package = pkgs.fabricServers.fabric-1_21_11;

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
                rcon-password = "localbackup";
                rcon-port = 25576;
              };
            };
          })

          (lib.mkIf cfg.forever-chu.enable {
            forever-chu = {
              enable = true;
              autoStart = true;
              jvmOpts = "-Xms2G -Xmx5G";
              package = pkgs.fabricServers.fabric-1_21_5.override {
                loaderVersion = "0.16.14";
              };

              serverProperties = {
                spawn-protection = 0;
                server-port = 25565;
                motd = "cum.army";
                online-mode = false;
                max-players = 10;
                white-list = true;
                enable-status = false;
                hide-online-players = true;
                allow-flight = true;
                sync-chunk-writes = false;
                enable-rcon = true;
                rcon-password = "localbackup";
                rcon-port = 25575;
              };
            };
          })
        ];
      };
    }
    (lib.mkIf cfg.cum.enable {
      systemd.services.minecraft-server-cum.path = [ pkgs.git pkgs.git-lfs];
    })
    (lib.mkIf cfg.forever-chu.enable {
      systemd.services.minecraft-server-forever-chu.path = [ pkgs.git pkgs.git-lfs];
    })

    (lib.mkIf ((cfg.cum.enable || cfg.forever-chu.enable) && cfg.backup.enable) {
      age.secrets.resticMinecraftPassword = {
        owner = "minecraft";
        group = "minecraft";
        file = ../secrets/resticMinecraftPassword;
      };

      systemd.tmpfiles.rules = [
        "d /srv/backups/minecraft 0750 minecraft minecraft -"
      ];

      services.restic.backups.minecraft = {
        user = "minecraft";
        repository = "/srv/backups/minecraft";
        passwordFile = config.age.secrets.resticMinecraftPassword.path;
        initialize = true;
        paths = (lib.optionals cfg.cum.enable [ "/srv/minecraft/cum" ])
              ++ (lib.optionals cfg.forever-chu.enable [ "/srv/minecraft/forever-chu" ]);
        exclude = [
          "logs"
          "crash-reports"
          "hs_err_pid*.log"
          "**/DistantHorizons.sqlite"
        ];
        pruneOpts = [
          "--keep-daily 1"
          "--keep-weekly 1"
          "--keep-monthly 2"
        ];
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
          if systemctl is-active --quiet minecraft-server-forever-chu.service; then
            ${pkgs.mcrcon}/bin/mcrcon -H 127.0.0.1 -P 25575 -p localbackup "save-off" || true
            ${pkgs.mcrcon}/bin/mcrcon -H 127.0.0.1 -P 25575 -p localbackup "save-all flush" || true
          fi
        '';
        backupCleanupCommand = ''
          set +e
          if systemctl is-active --quiet minecraft-server-cum.service; then
            ${pkgs.mcrcon}/bin/mcrcon -H 127.0.0.1 -P 25576 -p localbackup "save-on" || true
          fi
          if systemctl is-active --quiet minecraft-server-forever-chu.service; then
            ${pkgs.mcrcon}/bin/mcrcon -H 127.0.0.1 -P 25575 -p localbackup "save-on" || true
          fi
        '';
      };
    })
  ];
}
