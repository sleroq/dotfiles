{
  config,
  inputs,
  lib,
  pkgs,
  secrets,
  ...
}:
let
  mongoImage = "docker.io/library/mongo@sha256:6189a342f8da4568b4b111c378a890b1fe186b1bc133742bff8811fe63d2e01e";
  countlyImage = "docker.io/countly/countly-server@sha256:5a6b3051a0db968ee3f8b2a23e9ee362af249bbc228f868c45bceb3944f9ae56";
  productionMarker = "/var/lib/roundy/production-enabled";
in
{
  system.extraDependencies = [
    inputs.starflake.outPath
    inputs.roundy.outPath
  ];

  age.secrets = {
    roundyEnv = {
      file = ./secrets/roundyEnv;
      owner = "roundy";
      group = "roundy";
    };
    mongoEnv.file = ./secrets/mongoEnv;
    mongo-logsEnv.file = ./secrets/mongo-logsEnv;
  };

  users.users.roundy = {
    isSystemUser = true;
    group = "roundy";
    home = "/var/lib/roundy";
  };
  users.groups.roundy = { };

  services.starflake = {
    enable = true;
    metrics.listenAddress = "127.0.0.1";
    deployments.roundy = {
      # Immutable, rooted initial release; publish packaging before enabling updates.
      source.url = "path:${inputs.roundy.outPath}";
      initialPackage = inputs.roundy.packages.${pkgs.stdenv.hostPlatform.system}.default;
      runtime = {
        exec = [ "bin/roundy" ];
        user = "roundy";
        group = "roundy";
        environmentFiles = [ config.age.secrets.roundyEnv.path ];
      };
      state.dataDir = "/var/lib/roundy";
      poll.enable = false;
      build.allowLocalBuild = false;
      update.retainGenerations = 3;
      health.checks.http.url = "http://127.0.0.1:3000/v";
    };
  };

  # Rebuilds, reboots and accidental manual starts must not activate a second poller.
  systemd.services.starflake-app-roundy = {
    unitConfig.ConditionPathExists = productionMarker;
    after = [
      "podman-mongo.service"
      "podman-mongo-logs.service"
    ];
    serviceConfig = {
      MemoryMax = "1G";
      MemorySwapMax = "512M";
    };
  };
  systemd.services.starflake-reconcile-roundy = {
    wantedBy = lib.mkForce [ ];
    unitConfig.ConditionPathExists = productionMarker;
  };

  virtualisation = {
    podman.enable = true;
    oci-containers = {
      backend = "podman";
      containers = {
        mongo = {
          image = mongoImage;
          environmentFiles = [ config.age.secrets.mongoEnv.path ];
          ports = [ "127.0.0.1:27017:27017" ];
          volumes = [
            "/var/lib/roundy-mongo/data:/data/db"
            "/var/lib/roundy-mongo/config:/data/configdb"
          ];
          cmd = [
            "mongod"
            "--wiredTigerCacheSizeGB"
            "0.25"
          ];
          extraOptions = [
            "--memory=1g"
            "--log-driver=journald"
          ];
        };
        mongo-logs = {
          image = mongoImage;
          environmentFiles = [ config.age.secrets.mongo-logsEnv.path ];
          ports = [ "127.0.0.1:27018:27017" ];
          volumes = [
            "/var/lib/roundy-mongo-logs/data:/data/db"
            "/var/lib/roundy-mongo-logs/config:/data/configdb"
          ];
          cmd = [
            "mongod"
            "--wiredTigerCacheSizeGB"
            "0.25"
          ];
          extraOptions = [
            "--memory=512m"
            "--log-driver=journald"
          ];
        };
        # Retain this legacy stack intact; upgrading it is a separate project.
        countly = {
          image = countlyImage;
          autoStart = false;
          ports = [ "127.0.0.1:8090:80" ];
          volumes = [ "/var/lib/countly/data:/var/lib/mongodb" ];
          extraOptions = [
            "--memory=2g"
            "--log-driver=journald"
          ];
        };
      };
    };
  };
  systemd.services.podman-countly.unitConfig.ConditionPathExists =
    "/var/lib/countly/production-enabled";

  systemd.tmpfiles.rules = [
    # Preserve the pinned Mongo image's ownership across rebuilds and reboots.
    "d /var/lib/roundy-mongo/data 0700 999 999 -"
    "d /var/lib/roundy-mongo/config 0700 999 999 -"
    "d /var/lib/roundy-mongo-logs/data 0700 999 999 -"
    "d /var/lib/roundy-mongo-logs/config 0700 999 999 -"
    "d /var/lib/countly 0700 root root -"
    # UID/GID of mongodb in the pinned Countly image, verified before restore.
    "d /var/lib/countly/data 0700 107 65534 -"
    "d /var/backups/roundy 0700 root root -"
  ];

  # Obtain TLS now, but keep public bot/analytics routing blocked until cutover.
  services.caddy = {
    enable = true;
    virtualHosts = {
      "http://${secrets.ipv4}".extraConfig = ''
        respond /healthz "migration staging" 200
        respond "Production cutover has not been authorized" 503
      '';
      "roundy.sleroq.link".extraConfig = ''
        respond /healthz "migration staging" 200
        respond "Production cutover has not been authorized" 503
      '';
      "countly.sleroq.link".extraConfig = ''
        respond /healthz "migration staging" 200
        respond "Production cutover has not been authorized" 503
      '';
      # Starflake enforces loopback; the firewall restricts this proxy to cumserver.
      "http://:9599".extraConfig = ''
        reverse_proxy 127.0.0.1:9598
      '';
    };
  };

  environment.systemPackages = [ pkgs.mongodb-tools ];
}
