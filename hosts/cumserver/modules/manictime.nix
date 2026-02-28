{ config, lib, ... }:
let
  cfg = config.cumserver.manictime;
in
{
  options.cumserver.manictime = {
    enable = lib.mkEnableOption "ManicTime Server";

    image = lib.mkOption {
      type = lib.types.str;
      default = "manictime/manictimeserver:latest";
      description = "Docker image to use for ManicTime Server";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "time.cum.army";
      description = "Domain name for ManicTime Server";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Internal port for ManicTime Server";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/manictimeserver/Data";
      description = "Data directory for ManicTime Server";
    };

    extraOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional options to pass to the container";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.virtualisation.oci-containers.backend != null;
        message = "OCI containers backend must be configured for ManicTime Server to work";
      }
      {
        assertion = config.services.caddy.enable;
        message = "Caddy has to be enabled for ManicTime Server to work";
      }
    ];

    virtualisation.oci-containers.containers.manictime = {
      autoStart = true;
      pull = "newer";
      inherit (cfg) image extraOptions;
      ports = [ "127.0.0.1:${toString cfg.port}:8080" ];
      volumes = [
        "${cfg.dataDir}:/app/Data"
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
