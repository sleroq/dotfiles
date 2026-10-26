{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cumserver.traggo;
in
{
  options.cumserver.traggo = {
    enable = lib.mkEnableOption "Traggo time tracking application";

    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/traggo/server:0.8.3@sha256:8bf510774ce1729b5bd9a8930e174de03ebec8c25ca4aaa087c0e56e2bcbb67a";
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
      default = { };
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

    services.restic.backups.traggo = {
      user = "root";
      repository = "s3:https://b9b008414ac92325dff304821d2a0a2c.eu.r2.cloudflarestorage.com/bots-backups";
      passwordFile = config.age.secrets.resticBackupsPassword.path;
      environmentFile = config.age.secrets.resticS3Keys.path;
      initialize = true;
      backupPrepareCommand = ''
        set -euo pipefail
        umask 077
        install -d -m 0700 "${cfg.dataDir}/backup"
        dump=$(mktemp "${cfg.dataDir}/backup/.traggo.db.XXXXXX")
        trap 'rm -f "$dump"' EXIT
        ${pkgs.sqlite}/bin/sqlite3 -readonly "${cfg.dataDir}/traggo.db" \
          ".backup '$dump'"
        mv "$dump" "${cfg.dataDir}/backup/traggo.db"
      '';
      paths = [ cfg.dataDir ];
      exclude = [
        "${cfg.dataDir}/traggo.db"
        "${cfg.dataDir}/traggo.db-wal"
        "${cfg.dataDir}/traggo.db-shm"
        "${cfg.dataDir}/traggo.db-journal"
      ];
      # Reactor owns repository-wide retention for bots-backups.
      timerConfig = {
        OnCalendar = "05:45";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root -"
    ];
  };
}
