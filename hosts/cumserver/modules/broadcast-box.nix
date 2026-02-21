{
  inputs',
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.cumserver.broadcast-box;
  enabledInstances = if cfg.enable then cfg.instances else { };
  instanceList = lib.mapAttrsToList (name: instance: instance // { inherit name; }) enabledInstances;
  backupInstances = lib.filterAttrs (_: instance: instance.backup.enable) enabledInstances;
  nat1to1Ip = (builtins.head config.networking.interfaces.ens3.ipv4.addresses).address;

  envValueToString =
    value:
    if (builtins.typeOf value == "bool") then
      if value then "true" else "false"
    else if (builtins.typeOf value == "int") then
      toString value
    else
      value;

  mkRedisServer = name: instance: {
    enable = true;
    bind = "127.0.0.1";
    port = instance.redisPort;
    appendOnly = true;
    save = [
      [
        60
        1
      ]
      [
        300
        10
      ]
    ];
  };

  mkServiceEnvironment = name: instance:
    let
      defaultSettings = {
        REDIS_URL = "redis://localhost:${toString instance.redisPort}/${toString instance.redisDb}";
        UDP_MUX_PORT = instance.udpPort;
        NETWORK_TYPES = "udp4";
        NAT_1_TO_1_IP = nat1to1Ip;
        NETWORK_TEST_ON_START = "false";
        LOGGING_DIRECTORY = "/var/lib/private/${instance.stateDirectory}/logs";
        STREAM_PROFILE_PATH = "/var/lib/private/${instance.stateDirectory}/profiles";
        DISABLE_STATUS = "false";
        DISABLE_FRONTEND = "true";
      };
      resolvedSettings = defaultSettings // instance.settings;
    in
    (lib.mapAttrs (_: envValueToString) resolvedSettings)
    // {
      APP_ENV = "nixos";
      HTTP_ADDRESS = "127.0.0.1:${toString instance.port}";
    };

  mkService = name: instance:
    let
      serviceName = "broadcast-box-${name}";
      redisService = "redis-broadcast-box-${name}.service";
      privilegedPort = instance.udpPort < 1024 || instance.port < 1024;
    in
    {
      description = "Broadcast Box (${name})";
      after = [
        "network-online.target"
        redisService
      ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      startLimitBurst = 3;
      startLimitIntervalSec = 180;

      environment = mkServiceEnvironment name instance;

      serviceConfig = {
        ExecStart = lib.getExe pkgs.broadcast-box;
        Restart = "always";
        RestartSec = "10s";

        WorkingDirectory = "/var/lib/private/${instance.stateDirectory}";
        StateDirectory = instance.stateDirectory;
        StateDirectoryMode = "0700";
        RuntimeDirectory = serviceName;
        RuntimeDirectoryMode = "0750";

        DynamicUser = true;
        LockPersonality = true;
        NoNewPrivileges = true;
        PrivateUsers = !privilegedPort;
        PrivateDevices = true;
        PrivateMounts = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectControlGroups = true;
        ProtectClock = true;
        ProtectProc = "invisible";
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProcSubset = "pid";
        RemoveIPC = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_NETLINK"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
        ];
        CapabilityBoundingSet = if privilegedPort then [ "CAP_NET_BIND_SERVICE" ] else "";
        AmbientCapabilities = if privilegedPort then [ "CAP_NET_BIND_SERVICE" ] else [ ];
        DeviceAllow = "";
        MemoryDenyWriteExecute = true;
        UMask = "0077";
      };
    };

  mkCaddyVirtualHost = name: instance: {
    extraConfig = ''
      @websockets {
        header Connection *Upgrade*
        header Upgrade websocket
      }

      # Force directive ordering so that headers are applied to both
      # proxied requests and the response.
      route {
        header {
          X-Content-Type-Options nosniff
          X-Frame-Options DENY
          X-XSS-Protection "1; mode=block"
          Referrer-Policy strict-origin-when-cross-origin
        }

        # API and WebSockets go to the container
        handle /api/* {
          reverse_proxy @websockets 127.0.0.1:${toString instance.port}
          reverse_proxy 127.0.0.1:${toString instance.port}
        }

        # Everything else serves the static frontend from web-cum-army
        handle {
          root * ${
            inputs'.web-cum-army.packages.default.override {
              siteTitle = if name == "production" then "Broadcast Box" else "Broadcast Box (${name})";
              apiPath = "https://${instance.domain}/api";
            }
          }

          @index {
            file
            path / /index.html
          }
          header @index Cache-Control "no-cache, no-store, must-revalidate"

          @static {
            file
            path *.js *.css *.png *.jpg *.jpeg *.gif *.svg *.woff *.woff2
          }
          header @static Cache-Control "public, max-age=31536000, immutable"

          try_files {path} /index.html
          file_server
          encode zstd gzip
        }
      }
    '';
  };

  mkBackup = name: instance: {
    user = "root";
    repository = "s3:https://b9b008414ac92325dff304821d2a0a2c.eu.r2.cloudflarestorage.com/bots-backups";
    passwordFile = config.age.secrets.resticBackupsPassword.path;
    environmentFile = config.age.secrets.resticS3Keys.path;
    initialize = true;
    paths = [ "/var/lib/redis-broadcast-box-${name}" ];
    pruneOpts = [
      "--keep-daily 1"
      "--keep-weekly 5"
      "--keep-monthly 12"
    ];
    timerConfig = {
      OnCalendar = "04:40";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
    backupPrepareCommand = ''
      set +e
      if systemctl is-active --quiet redis-broadcast-box-${name}.service; then
        ${config.services.redis.package}/bin/redis-cli -h 127.0.0.1 -p ${toString instance.redisPort} SAVE || true
      fi
    '';
  };
in
{
  options.cumserver.broadcast-box = {
    enable = lib.mkEnableOption "Broadcast Box WebRTC streaming server";

    instances = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              backup.enable = lib.mkEnableOption "backups" // {
                default = true;
              };

              domain = lib.mkOption {
                type = lib.types.str;
                description = "Domain name for Broadcast Box";
                example = "broadcast.example.com";
              };

              port = lib.mkOption {
                type = lib.types.port;
                description = "Internal port for Broadcast Box HTTP server";
              };

              udpPort = lib.mkOption {
                type = lib.types.port;
                description = "UDP port for WebRTC traffic";
              };

              redisPort = lib.mkOption {
                type = lib.types.port;
                description = "Redis port used by this instance";
              };

              redisDb = lib.mkOption {
                type = lib.types.ints.between 0 15;
                default = 0;
                description = "Redis database index used by this instance";
              };

              stateDirectory = lib.mkOption {
                type = lib.types.str;
                default = "broadcast-box-${name}";
                description = "State directory name under /var/lib/private for Broadcast Box";
              };

              settings = lib.mkOption {
                type =
                  with lib.types;
                  attrsOf (
                    nullOr (oneOf [
                      bool
                      int
                      str
                    ])
                  );
                default = { };
                description = "Extra Broadcast Box environment variables";
              };
            };
          }
        )
      );
      default = { };
      description = "Broadcast Box deployments keyed by instance name";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.services.caddy.enable;
          message = "broadcast-box requires Caddy to be enabled for reverse proxy. Set services.caddy.enable = true";
        }
        {
          assertion = enabledInstances != { };
          message = "broadcast-box is enabled but no instances were configured";
        }
        {
          assertion = lib.allUnique (map (instance: instance.domain) instanceList);
          message = "broadcast-box instances must use unique domains";
        }
        {
          assertion = lib.allUnique (map (instance: instance.port) instanceList);
          message = "broadcast-box instances must use unique HTTP ports";
        }
        {
          assertion = lib.allUnique (map (instance: instance.udpPort) instanceList);
          message = "broadcast-box instances must use unique UDP ports";
        }
        {
          assertion = lib.allUnique (map (instance: instance.redisPort) instanceList);
          message = "broadcast-box instances must use unique Redis ports";
        }
        {
          assertion = lib.allUnique (map (instance: instance.stateDirectory) instanceList);
          message = "broadcast-box instances must use unique state directories";
        }
      ];

      services.redis.servers = lib.mapAttrs' (name: instance: lib.nameValuePair "broadcast-box-${name}" (mkRedisServer name instance)) enabledInstances;

      systemd.services = lib.mapAttrs' (name: instance: lib.nameValuePair "broadcast-box-${name}" (mkService name instance)) enabledInstances;

      networking.firewall = {
        allowedUDPPorts = map (instance: instance.udpPort) instanceList;
      };

      services.caddy.virtualHosts = lib.mapAttrs' (name: instance: lib.nameValuePair instance.domain (mkCaddyVirtualHost name instance)) enabledInstances;
    })

    (lib.mkIf cfg.enable {
      services.restic.backups = lib.mapAttrs' (name: instance: lib.nameValuePair "broadcast-box-redis-${name}" (mkBackup name instance)) backupInstances;
    })
  ];
}
