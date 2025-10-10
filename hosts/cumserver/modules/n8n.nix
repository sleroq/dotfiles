{ config, lib, ... }:

let
  cfg = config.cumserver.n8n;
in
{
  options.cumserver.n8n = {
    enable = lib.mkEnableOption "n8n via OCI container";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "n8n.cum.army";
      description = "Domain name for n8n";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5678;
      description = "Internal port for n8n HTTP server";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.n8n.io/n8nio/n8n:latest";
      description = "Docker image to use for n8n";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/n8n";
      description = "Persistent data directory on host, mounted at /home/node/.n8n";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to environment file containing sensitive configuration";
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Additional environment variables";
      example = {
        DB_TYPE = "postgresdb";
        DB_POSTGRESDB_HOST = "127.0.0.1";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.virtualisation.oci-containers.backend != null;
        message = "OCI containers backend must be configured for n8n to work";
      }
      {
        assertion = config.services.caddy.enable;
        message = "n8n requires Caddy to be enabled for reverse proxy. Set services.caddy.enable = true";
      }
    ];

    # Create n8n user with UID 1000 to match container's node user
    users.users.n8n = {
      uid = 1000;
      isSystemUser = true;
      group = "n8n";
      home = cfg.dataDir;
      createHome = true;
    };

    users.groups.n8n = {};

    # Ensure data directory exists with correct ownership
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 n8n n8n -"
    ];

    virtualisation.oci-containers.containers.n8n = {
      inherit (cfg) image;
      autoStart = true;
      pull = "newer";

      ports = [
        "127.0.0.1:${toString cfg.port}:5678"
      ];

      volumes = [
        "${cfg.dataDir}:/home/node/.n8n"
      ];

      environment = {
        GENERIC_TIMEZONE = "UTC";
        TZ = "UTC";
        N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS = "true";
        N8N_RUNNERS_ENABLED = "true";
        N8N_DIAGNOSTICS_ENABLED = "true";
        N8N_VERSION_NOTIFICATIONS_ENABLED = "true";
        WEBHOOK_URL = "https://${cfg.domain}";
      } // cfg.extraEnvironment;

      environmentFiles = lib.optional (cfg.environmentFile != null) cfg.environmentFile;

      extraOptions = [
        "--hostname=n8n"
      ];
    };

    services.caddy.virtualHosts.${cfg.domain} = {
      extraConfig = ''
        reverse_proxy 127.0.0.1:${toString cfg.port}
        encode zstd gzip

        header {
          X-Content-Type-Options nosniff
          X-Frame-Options SAMEORIGIN
          X-XSS-Protection "1; mode=block"
        }
      '';
    };
  };
}

