{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.navidrome;
in
{
  options.services.navidrome = {
    musicFolder = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/navidrome/music";
      description = "Path to music files";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address on which Navidrome listens";
    };

    metrics = {
      enable = lib.mkEnableOption "Navidrome Prometheus metrics";

      path = lib.mkOption {
        type = lib.types.str;
        default = "/metrics";
        description = "Path for the Navidrome metrics endpoint";
      };
    };

    cloudflared.tokenFile = lib.mkOption {
      type = lib.types.path;
      description = "File containing the token for a remotely managed Cloudflare Tunnel";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.musicFolder} 0755 navidrome navidrome -"
    ];

    services.navidrome = {
      openFirewall = false;
      settings = {
        Address = cfg.listenAddress;
        Port = 4533;
        MusicFolder = cfg.musicFolder;
        DataFolder = "/var/lib/navidrome/data";
        CacheFolder = "/var/lib/navidrome/cache";
        ScanSchedule = "1h";
        LogLevel = "info";
        SessionTimeout = "24h";
        EnableSharing = true;
        Prometheus = {
          Enabled = cfg.metrics.enable;
          MetricsPath = cfg.metrics.path;
        };
      };
    };

    systemd.services.cloudflared-navidrome = {
      description = "Cloudflare Tunnel for Navidrome";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = "${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run --token-file %d/token";
        LoadCredential = "token:${cfg.cloudflared.tokenFile}";
        DynamicUser = true;
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
