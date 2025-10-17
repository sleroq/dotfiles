{ pkgs, config, lib, ... }:

let
  cfg = config.cumserver.minecraft;
in
{
  options.cumserver.minecraft = {
      cum.enable = lib.mkEnableOption "cum.army minecraft server";
      forever-chu.enable = lib.mkEnableOption "Forever Chu minecraft server";
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
              jvmOpts = "-Xms2G -Xmx4G";
              package = pkgs.fabricServers.fabric-1_21_5.override {
                loaderVersion = "0.16.14";
              };

              serverProperties = {
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
              };
            };
          })

          (lib.mkIf cfg.forever-chu.enable {
            forever-chu = {
              enable = true;
              autoStart = true;
              jvmOpts = "-Xms2G -Xmx3G";
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
  ];
}
