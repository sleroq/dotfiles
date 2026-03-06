{ config, lib, ... }:
let
  cfg = config.cumserver.slusha;
in
{
  options.cumserver.slusha = {
    enable = lib.mkEnableOption "Slusha telegram bot (OCI container)";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "slusha.cum.army";
      description = "Domain name for Slusha web app";
    };

    webPort = lib.mkOption {
      type = lib.types.port;
      default = 18080;
      description = "Host loopback port used for Slusha web app reverse proxy";
    };

    backup.enable = lib.mkEnableOption "backups" // { default = true; };

    image = lib.mkOption {
      type = lib.types.str;
      default = "localhost/slusha:latest";
      description = "Container image to use for Slusha";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/slusha";
      description = "Persistent data directory for Slusha (for tmp, log, data with sqlite files)";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Environment file containing secrets (e.g., BOT_TOKEN, AI_TOKEN)";
    };

    configFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to slusha.config.js to mount read-only inside the container";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "slusha";
      description = "Host user to own dataDir and run the container";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "slusha";
      description = "Host group to own dataDir and run the container";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.virtualisation.oci-containers.backend != null;
          message = "OCI containers backend must be configured for Slusha to work";
        }
        {
          assertion = config.services.caddy.enable;
          message = "Slusha requires Caddy to be enabled for reverse proxy. Set services.caddy.enable = true";
        }
      ];

      users.users.${cfg.user} = {
        isSystemUser = true;
        group = cfg.group;
        home = cfg.dataDir;
        createHome = true;
      };

      users.groups.${cfg.group} = {};

      # Ensure persistent dirs and files exist with correct ownership
      systemd.tmpfiles.rules = [
        "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} -"
        "d ${cfg.dataDir}/tmp 0750 ${cfg.user} ${cfg.group} -"
        "d ${cfg.dataDir}/log 0750 ${cfg.user} ${cfg.group} -"
        "d ${cfg.dataDir}/data 0750 ${cfg.user} ${cfg.group} -"
      ];

      virtualisation.oci-containers.containers.slusha = {
        inherit (cfg) image;
        autoStart = true;
        pull = "newer";

        ports = [
          "127.0.0.1:${toString cfg.webPort}:8080"
        ];

        environmentFiles = lib.optional (cfg.environmentFile != null) cfg.environmentFile;

        volumes = [
          "${cfg.dataDir}/data:/home/nonroot/app/data:U"
          "${cfg.dataDir}/tmp:/home/nonroot/app/tmp:U"
          "${cfg.dataDir}/log:/home/nonroot/app/log:U"
        ] ++ lib.optional (cfg.configFile != null) "${cfg.configFile}:/home/nonroot/app/slusha.config.js:ro";
      };

      services.caddy.virtualHosts.${cfg.domain} = {
        extraConfig = ''
          reverse_proxy 127.0.0.1:${toString cfg.webPort}
          encode zstd gzip
        '';
      };
    })

    (lib.mkIf (cfg.enable && cfg.backup.enable) {
      users.groups.restic-backups.members = [ cfg.user ];
      users.groups.restic-s3-backups.members = [ cfg.user ];

      services.restic.backups.slusha = {
        user = cfg.user;
        repository = "s3:https://b9b008414ac92325dff304821d2a0a2c.eu.r2.cloudflarestorage.com/bots-backups";
        passwordFile = config.age.secrets.resticBackupsPassword.path;
        environmentFile = config.age.secrets.resticS3Keys.path;
        initialize = true;
        paths = [ cfg.dataDir ];
        exclude = [ "log" "tmp" ];
        pruneOpts = [
          "--keep-daily 1"
          "--keep-weekly 3"
          "--keep-monthly 5"
        ];
        timerConfig = {
          OnCalendar = "03:35";
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
      };
    })
  ];
}
