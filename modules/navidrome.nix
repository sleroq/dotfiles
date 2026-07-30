{
  config,
  lib,
  ...
}:

let
  cfg = config.sleroq.navidrome;
in
{
  options.sleroq.navidrome = {
    enable = lib.mkEnableOption "Navidrome with the Cloudflare tunnel";

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

    environmentFile = lib.mkOption {
      type = lib.types.path;
      description = "File containing Navidrome environment variables";
    };

    metrics = {
      enable = lib.mkEnableOption "Navidrome Prometheus metrics";

      path = lib.mkOption {
        type = lib.types.str;
        default = "/metrics";
        description = "Path for the Navidrome metrics endpoint";
      };
    };

    cloudflared = {
      tunnel = lib.mkOption {
        type = lib.types.str;
        description = "Name of the locally managed Cloudflare Tunnel that routes to Navidrome.";
      };

      hostname = lib.mkOption {
        type = lib.types.str;
        description = "Public hostname for Navidrome.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.musicFolder} 0755 navidrome navidrome -"
    ];

    services.navidrome = {
      enable = true;
      openFirewall = false;
      inherit (cfg) environmentFile;
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

    sleroq.cloudflared.tunnels.${cfg.cloudflared.tunnel}.routes.${cfg.cloudflared.hostname} = "http://127.0.0.1:4533";
  };
}
