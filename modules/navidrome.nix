{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.sleroq.navidrome;
  musicLinkPackage = inputs.music-link.lib.${pkgs.stdenv.hostPlatform.system}.makePackage {
    themes = [
      "base"
      "daylight"
      "phosphor"
    ];
    defaultTheme = "phosphor";
  };
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

    systemd.services.music-link = {
      description = "music-link Navidrome share page server";
      wantedBy = [ "multi-user.target" ];
      after = [ "navidrome.service" ];
      environment.MUSIC_LINK_SITE_URL = "https://${cfg.cloudflared.hostname}";
      serviceConfig = {
        DynamicUser = true;
        ExecStart = "${musicLinkPackage}/bin/music-link";
      };
    };

    # Navidrome retains its UI and native share capability URLs; music-link
    # renders only share pages and its static assets.
    sleroq.cloudflared.tunnels.${cfg.cloudflared.tunnel}.routes.${cfg.cloudflared.hostname} =
      "http://127.0.0.1:80";

    services.caddy = {
      enable = true;
      virtualHosts."http://${cfg.cloudflared.hostname}".extraConfig = ''
        encode zstd gzip

        route {
          # Native capability URLs bypass music-link so Navidrome retains range
          # requests, expiration, revocation, and download enforcement.
          @navidrome path_regexp ^/share/(?:s/.*|img/.*|d/.*|[A-Za-z0-9_-]{1,128}/m3u/?$)
          handle @navidrome {
            reverse_proxy 127.0.0.1:4533
          }

          # music-link owns its share routes and strips /_music-link itself
          # when serving the built assets.
          @music_link path /share/* /_music-link/*
          handle @music_link {
            reverse_proxy 127.0.0.1:8787
          }

          # Navidrome owns its UI and all non-share routes.
          handle {
            reverse_proxy 127.0.0.1:4533
          }
        }
      '';
    };
  };
}
