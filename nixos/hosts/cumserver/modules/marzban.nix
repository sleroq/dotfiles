{ config, lib, pkgs, ... }:
let
  cfg = config.cumserver.marzban;
in
{
  options.cumserver.marzban = {
    enable = lib.mkEnableOption "Marzban proxy management panel";

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/gozargah/marzban:latest";
      description = "Docker image to use for Marzban";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "uwu.sleroq.link";
      description = "Domain name for Marzban";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "Internal port for Marzban";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/marzban";
      description = "Data directory for Marzban";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Environment file containing Marzban configuration";
    };

    extraOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "--network=host" ];
      description = "Additional options to pass to the container";
    };

    metricsEnvironmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Environment file containing Marzban metrics exporter configuration";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.virtualisation.oci-containers.backend != null;
        message = "OCI containers backend must be configured for Marzban to work";
      }
      {
        assertion = config.services.caddy.enable;
        message = "Caddy has to be enabled for Marzban to work";
      }
    ];

    virtualisation.oci-containers.containers = {
      marzban = {
        autoStart = true;
        image = cfg.image;
        environmentFiles = lib.optional (cfg.environmentFile != null) cfg.environmentFile;
        environment = {
          UVICORN_HOST = "127.0.0.1";
          UVICORN_PORT = toString cfg.port;
          XRAY_JSON = "/var/lib/marzban/xray_config.json";
          SQLALCHEMY_DATABASE_URL = "sqlite:////var/lib/marzban/db.sqlite3";
        };
        extraOptions = cfg.extraOptions;
        volumes = [
          "${cfg.dataDir}:/var/lib/marzban"
        ];
      };
    } // lib.optionalAttrs (config.cumserver.monitoring.enable && cfg.metricsEnvironmentFile != null) {
      marzban-exporter = {
        autoStart = true;
        image = "kutovoys/marzban-exporter:latest";
        environmentFiles = [ cfg.metricsEnvironmentFile ];
        ports = [ "127.0.0.1:9091:9090" ];
        dependsOn = [ "marzban" ];
      };
    };

    services.caddy.virtualHosts.${cfg.domain} = {
      extraConfig = ''
        reverse_proxy 127.0.0.1:${toString cfg.port}
        
        header {
          X-Content-Type-Options nosniff
          X-Frame-Options SAMEORIGIN
          X-XSS-Protection "1; mode=block"
          X-Real-IP {remote_addr}
          X-Forwarded-For {remote_addr}
          X-Forwarded-Host {host}
        }
        
        encode zstd gzip
      '';
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root -"
    ];

    networking.firewall.allowedTCPPorts = [
      2080 # vless
      8081 # vmess
    ];
  };
} 