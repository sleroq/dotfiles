{
  config,
  inputs,
  inputs',
  lib,
  ...
}:
{
  # Keep the unpublished controller source available for future host evaluations.
  # TODO: remove this once the controller is published.
  system.extraDependencies = [ inputs.starflake.outPath ];

  age.secrets = {
    bayanEnv = {
      owner = "bayan";
      group = "bayan";
      file = ../secrets/bayanEnv;
    };
    spoiler-imagesEnv = {
      owner = "spoiler-images";
      group = "spoiler-images";
      file = ../secrets/spoilerImagesEnv;
    };
  };

  services.starflake = {
    enable = true;

    deployments = {
      reactor = {
        source = {
          url = "github:sleroq/reactor/main";
          package = "default";
        };
        initialPackage = inputs'.reactor.packages.default;
        runtime = {
          exec = [ "bin/reactor" ];
          user = "reactor";
          group = "reactor";
          environment.REACTOR_SESSION_DIR = "/var/lib/reactor";
          environmentFiles = [ config.age.secrets.reactorEnv.path ];
        };
        state.dataDir = "/var/lib/reactor";
        poll.interval = "10m";
        update.retainGenerations = 3;
      };

      spoiler-images = {
        source.url = "github:sleroq/spoiler-images/master";
        runtime = {
          exec = [ "bin/spoiler-images" ];
          user = "spoiler-images";
          group = "spoiler-images";
          environmentFiles = [ config.age.secrets.spoiler-imagesEnv.path ];
        };
        initialPackage = inputs'.spoiler-images.packages.default;
        poll.interval = "10m";
      };

      bayan = {
        source.url = "github:sleroq/bayan/main";
        # CI publishes this exact flake package to the trusted Bayan cache.
        build.allowLocalBuild = false;
        runtime = {
          exec = [ "bin/bayan" ];
          user = "bayan";
          group = "bayan";
          environmentFiles = [ config.age.secrets.bayanEnv.path ];
        };
        state.dataDir = "/var/lib/bayan";
        # The installed input predates the upstream vendorHash fix.
        initialPackage = inputs'.bayan.packages.default.overrideAttrs (_: {
          vendorHash = "sha256-xmunloo879R+BJHcbHOSoWgU9dCc0esDSGj5/QqSzao=";
        });
        poll.interval = "10m";
        update.retainGenerations = 3;
      };
    };
  };

  users.users = {
    reactor = {
      uid = 988;
      isSystemUser = true;
      group = "reactor";
      home = "/var/lib/reactor";
      createHome = true;
    };
    bayan = {
      isSystemUser = true;
      group = "bayan";
      home = "/var/lib/bayan";
    };
    spoiler-images = {
      isSystemUser = true;
      group = "spoiler-images";
    };
  };
  users.groups.reactor.gid = 986;
  users.groups.bayan = { };
  users.groups.spoiler-images = { };

  users.groups.restic-backups.members = [ "bayan" ];
  users.groups.restic-s3-backups.members = [ "bayan" ];
  services.restic.backups.bayan = {
    user = "bayan";
    repository = "s3:https://b9b008414ac92325dff304821d2a0a2c.eu.r2.cloudflarestorage.com/bots-backups";
    passwordFile = config.age.secrets.resticBackupsPassword.path;
    environmentFile = config.age.secrets.resticS3Keys.path;
    initialize = true;
    paths = [ "/var/lib/bayan" ];
    exclude = [ "**/*.log" ];
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 5"
      "--keep-monthly 12"
    ];
    timerConfig = {
      OnCalendar = "03:35";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };

  services.prometheus.scrapeConfigs = lib.mkIf config.cumserver.monitoring.enable [
    {
      job_name = "starflake";
      static_configs = [
        { targets = [ "127.0.0.1:${toString config.services.starflake.metrics.port}" ]; }
        {
          targets = [ "div.capybara-menkent.ts.net:9599" ];
          labels.instance = "div";
        }
        {
          targets = [ "147.45.150.135:9599" ];
          labels.instance = "roundy";
        }
      ];
    }
  ];
}
