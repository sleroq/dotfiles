{ config, ... }:

{
  age.secrets.resticHtpasswd = {
    file = ./secrets/resticHtpasswd;
    owner = "restic";
    group = "restic";
  };
  age.secrets.resticMinecraftPassword = {
    file = ../cumserver/secrets/resticMinecraftPassword;
    owner = "restic";
    group = "restic";
  };

  services.restic.server = {
    enable = true;
    listenAddress = "100.110.59.70:8040";
    dataDir = "/srv/backups";
    appendOnly = true;
    privateRepos = true;
    htpasswd-file = config.age.secrets.resticHtpasswd.path;
  };
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 8040 ];

  systemd.tmpfiles.rules = [
    "d /srv/backups 0750 restic restic -"
  ];

  # Maintenance bypasses the append-only REST endpoint using local disk access.
  services.restic.backups.minecraft-retention = {
    user = "restic";
    repository = "/srv/backups/minecraft";
    passwordFile = config.age.secrets.resticMinecraftPassword.path;
    pruneOpts = [
      "--keep-weekly 2"
      "--keep-monthly 4"
    ];
    runCheck = true;
    timerConfig = {
      OnCalendar = "Sun 06:00";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };
}
