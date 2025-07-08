{ config, lib, pkgs, ... }:

let
  cfg = config.cumserver.navidrome;
in
{
  options.cumserver.navidrome = {
    enable = lib.mkEnableOption "Navidrome music server";
    
    domain = lib.mkOption {
      type = lib.types.str;
      default = "music.cum.army";
      description = "Domain name for Navidrome";
    };
    
    musicFolder = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/navidrome/music";
      description = "Path to music files";
    };

    filebrowser = {
      enable = lib.mkEnableOption "FileBrowser web file manager";
      
      port = lib.mkOption {
        type = lib.types.port;
        default = 8099;
        description = "Internal port for FileBrowser";
      };
      
      baseUrl = lib.mkOption {
        type = lib.types.str;
        default = "/filebrowser";
        description = "Base URL path for FileBrowser";
      };
    };

    feishin = {
      enable = lib.mkEnableOption "Feishin music client";
      
      domain = lib.mkOption {
        type = lib.types.str;
        default = "feishin.cum.army";
        description = "Domain name for Feishin";
      };
      
      port = lib.mkOption {
        type = lib.types.port;
        default = 9180;
        description = "Internal port for Feishin";
      };
      
      image = lib.mkOption {
        type = lib.types.str;
        default = "ghcr.io/jeffvli/feishin:latest";
        description = "Docker image to use for Feishin";
      };
      
      serverName = lib.mkOption {
        type = lib.types.str;
        default = "sleroq";
        description = "Server name for Feishin";
      };
      
      serverUrl = lib.mkOption {
        type = lib.types.str;
        default = "https://music.cum.army";
        description = "URL of the Navidrome server";
      };
      
      timeZone = lib.mkOption {
        type = lib.types.str;
        default = "Europe/Moscow";
        description = "Time zone for Feishin container";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.caddy.enable;
        message = "Caddy has to be enabled for Navidrome to work";
      }
    ] ++ lib.optionals cfg.feishin.enable [
      {
        assertion = config.cumserver.podman.enable or config.virtualisation.podman.enable;
        message = "Feishin requires Podman to be enabled. Set cumserver.podman.enable = true or virtualisation.podman.enable = true";
      }
    ];

    age.secrets.navidromeEnv = {
      owner = "navidrome";
      group = "navidrome";
      file = ../secrets/navidromeEnv;
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/navidrome/music 0755 navidrome navidrome -"
    ];

    services.navidrome = {
      enable = true;
      openFirewall = false; # We'll use Caddy reverse proxy
      
      environmentFile = config.age.secrets.navidromeEnv.path;
      
      settings = {
        Address = "127.0.0.1";
        Port = 4533;
        
        MusicFolder = cfg.musicFolder;
        DataFolder = "/var/lib/navidrome/data";
        CacheFolder = "/var/lib/navidrome/cache";
        
        ScanSchedule = "1h";
        LogLevel = "info";
        SessionTimeout = "24h";
        BaseURL = "https://${cfg.domain}";
        
        Scanner.Extractor = "ffmpeg";
        EnableSharing = true;
        EnableInsightsCollector = false;
      };
    };

    services.filebrowser = lib.mkIf cfg.filebrowser.enable {
      enable = true;
      openFirewall = false; # We'll use Caddy reverse proxy
      user = "navidrome";
      group = "navidrome";
      
      settings = {
        address = "127.0.0.1";
        port = cfg.filebrowser.port;
        root = cfg.musicFolder;
        baseURL = cfg.filebrowser.baseUrl;
      };
    };

    virtualisation.oci-containers.containers.feishin = lib.mkIf cfg.feishin.enable {
      image = cfg.feishin.image;
      autoStart = true;
      
      ports = [
        "127.0.0.1:${toString cfg.feishin.port}:9180"
      ];
      
      environment = {
        SERVER_NAME = cfg.feishin.serverName;
        SERVER_LOCK = "true";
        SERVER_TYPE = "navidrome";
        SERVER_URL = cfg.feishin.serverUrl;
        PUID = "1000";
        PGID = "1000";
        UMASK = "002";
        TZ = cfg.feishin.timeZone;
      };
      
      extraOptions = [
        "--hostname=feishin"
      ];
    };

    services.caddy.virtualHosts = {
      ${cfg.domain} = {
        extraConfig = ''
          # FileBrowser on /filebrowser path
          ${lib.optionalString cfg.filebrowser.enable ''
          handle_path /filebrowser* {
            reverse_proxy localhost:${toString cfg.filebrowser.port}
            header {
              X-Content-Type-Options nosniff
              X-Frame-Options SAMEORIGIN
              X-XSS-Protection "1; mode=block"
            }
          }
          ''}
          
          # Navidrome for all other paths
          handle {
            reverse_proxy localhost:4533
          }
          
          encode zstd gzip
        '';
      };
    } // lib.optionalAttrs cfg.feishin.enable {
      ${cfg.feishin.domain} = {
        extraConfig = ''
          reverse_proxy localhost:${toString cfg.feishin.port}
          encode zstd gzip
          
          header {
            X-Content-Type-Options nosniff
            X-Frame-Options SAMEORIGIN
            X-XSS-Protection "1; mode=block"
          }
        '';
      };
    };
  };
}
