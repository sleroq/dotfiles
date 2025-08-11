{ config, lib, ... }:
let
  cfg = config.cumserver.traggo;
in
{
  options.cumserver.traggo = {
    enable = lib.mkEnableOption "Traggo time tracking application";

    image = lib.mkOption {
      type = lib.types.str;
      default = "traggo/server:latest";
      description = "Docker image to use for Traggo";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "time.cum.army";
      description = "Domain name for Traggo";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3030;
      description = "Internal port for Traggo";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/traggo";
      description = "Data directory for Traggo";
    };

    environment = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Environment variables for Traggo";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.virtualisation.oci-containers.backend != null;
        message = "OCI containers backend must be configured for Traggo to work";
      }
      {
        assertion = config.services.caddy.enable;
        message = "Caddy has to be enabled for Traggo to work";
      }
    ];

    virtualisation.oci-containers.containers.traggo = {
      inherit (cfg) image environment;
      autoStart = true;
      pull = "newer";
      ports = [ "127.0.0.1:${toString cfg.port}:3030" ];
      volumes = [
        "${cfg.dataDir}:/opt/traggo/data"
      ];
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
  };
} 
