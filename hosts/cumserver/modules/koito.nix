{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cumserver.koito;
  inherit (config.services.koito) environment;
  dbPath = "${environment.KOITO_CONFIG_DIR}/koito.db";
in
{
  options.cumserver.koito = {
    enable = lib.mkEnableOption "Koito music scrobbler";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "koito.cum.army";
      description = "Domain name for Koito";
    };

    environmentFile = lib.mkOption {
      type = lib.types.path;
      description = "Environment file for Koito";
    };

    subsonicUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Base URL of the Subsonic server used for artwork";
    };
  };

  config = lib.mkIf cfg.enable {
    services.koito = {
      enable = true;
      environment = {
        KOITO_LOGIN_GATE = "false";
      }
      // lib.optionalAttrs (cfg.subsonicUrl != null) {
        KOITO_SUBSONIC_URL = cfg.subsonicUrl;
      };
      inherit (cfg) environmentFile;
    };

    services.caddy.virtualHosts.${cfg.domain}.extraConfig = ''
      reverse_proxy 127.0.0.1:${toString environment.KOITO_LISTEN_PORT}
    '';

    services.restic.backups.koito = {
      repository = "s3:https://b9b008414ac92325dff304821d2a0a2c.eu.r2.cloudflarestorage.com/bots-backups";
      passwordFile = config.age.secrets.resticBackupsPassword.path;
      environmentFile = config.age.secrets.resticS3Keys.path;
      initialize = true;
      backupPrepareCommand = ''
        umask 077
        ${pkgs.sqlite}/bin/sqlite3 -readonly ${lib.escapeShellArg dbPath} \
          ".backup '$RUNTIME_DIRECTORY/koito.db'"
      '';
      paths = [ "/run/restic-backups-koito/koito.db" ];
      # Reactor owns repository-wide retention for bots-backups.
      timerConfig = {
        OnCalendar = "06:15";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };
  };
}
