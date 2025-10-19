{ config, lib, ... }:
let
  cfg = config.cumserver.slusha;
in
{
  options.cumserver.slusha = {
    enable = lib.mkEnableOption "Slusha telegram bot (OCI container)";

    backup.enable = lib.mkEnableOption "backups" // { default = true; };

    image = lib.mkOption {
      type = lib.types.str;
      default = "localhost/slusha:latest";
      description = "Container image to use for Slusha";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/slusha";
      description = "Persistent data directory for Slusha (for tmp, log, memory.json)";
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
        "f ${cfg.dataDir}/memory.json 0640 ${cfg.user} ${cfg.group} -"
      ];

      virtualisation.oci-containers.containers.slusha = {
        inherit (cfg) image;
        autoStart = true;
        pull = "newer";

        environmentFiles = lib.optional (cfg.environmentFile != null) cfg.environmentFile;

        volumes = [
          "${cfg.dataDir}/memory.json:/app/memory.json:U"
          "${cfg.dataDir}/tmp:/app/tmp:U"
          "${cfg.dataDir}/log:/app/log:U"
        ] ++ lib.optional (cfg.configFile != null) "${cfg.configFile}:/app/slusha.config.js:ro";
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
        exclude = [ "log" ];
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
