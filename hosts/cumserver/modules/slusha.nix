{ config, lib, ... }:
let
  cfg = config.cumserver.slusha;
in
{
  options.cumserver.slusha = {
    enable = lib.mkEnableOption "Slusha telegram bot (OCI container)";

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

  config = lib.mkIf cfg.enable {
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
  };
}

