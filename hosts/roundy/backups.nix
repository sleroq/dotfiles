{
  config,
  pkgs,
  secrets,
  ...
}:
{
  age.secrets = {
    resticPassword.file = ./secrets/resticPassword;
    resticS3Keys.file = ./secrets/resticS3Keys;
    mongoDumpConfig.file = ./secrets/mongoDumpConfig;
    mongo-logsDumpConfig.file = ./secrets/mongo-logsDumpConfig;
  };

  services.restic.backups.roundy = {
    user = "root";
    repository = secrets.resticRepository;
    passwordFile = config.age.secrets.resticPassword.path;
    environmentFile = config.age.secrets.resticS3Keys.path;
    initialize = true;
    paths = [ "/var/backups/roundy" ];
    backupPrepareCommand = ''
      #!${pkgs.runtimeShell}
      set -eu
      for database in mongo mongo-logs; do
        ${pkgs.mongodb-tools}/bin/mongodump \
          --config="/run/agenix/''${database}DumpConfig" \
          --archive="/var/backups/roundy/''${database}.archive.gz.next" --gzip
        mv "/var/backups/roundy/''${database}.archive.gz.next" "/var/backups/roundy/''${database}.archive.gz"
      done
      if test -e /var/lib/countly/production-enabled; then
        ${pkgs.podman}/bin/podman exec countly /usr/bin/mongodump --archive --gzip \
          > /var/backups/roundy/countly.archive.gz.next
        mv /var/backups/roundy/countly.archive.gz.next /var/backups/roundy/countly.archive.gz
      fi
    '';
    exclude = [ "*.next" ];
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 5"
      "--keep-monthly 12"
    ];
    timerConfig = {
      OnCalendar = "03:45";
      Persistent = true;
      RandomizedDelaySec = "30m";
    };
  };
  systemd.services.restic-backups-roundy.after = [
    "podman-mongo.service"
    "podman-mongo-logs.service"
  ];
}
