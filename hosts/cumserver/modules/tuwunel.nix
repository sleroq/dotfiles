{
  config,
  inputs',
  lib,
  secrets,
  pkgs,
  ...
}:
let
  cfg = config.cumserver.tuwunel;
  stateDirectory = "matrix-conduit";
  tomlFormat = pkgs.formats.toml { };
  guestDefaultUser = "tuwunel-guest";
  guestDefaultGroup = "tuwunel-guest";
in
{
  options.cumserver.tuwunel = {
    enable = lib.mkEnableOption "Tuwunel Matrix server";

    backup.enable = lib.mkEnableOption "backups" // {
      default = true;
    };

    mainDomain = lib.mkOption {
      type = lib.types.str;
      default = "sleroq.link";
      description = "Main domain name for the Matrix server";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "m.sleroq.link";
      description = "Domain name for the Matrix server";
    };

    clientDomain = lib.mkOption {
      type = lib.types.str;
      default = "cum.army";
      description = "Domain name used for Matrix web clients";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8008;
      description = "Internal port for the Matrix server";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.matrix-tuwunel;
      description = "The tuwunel package to use";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Additional settings for the Matrix server";
    };

    guest = {
      enable = lib.mkEnableOption "guest Tuwunel instance for anonymous calls";

      mainDomain = lib.mkOption {
        type = lib.types.str;
        default = "guest.sleroq.link";
        description = "Server-name domain for the guest Matrix instance";
      };

      domain = lib.mkOption {
        type = lib.types.str;
        default = "guest-m.sleroq.link";
        description = "Client-server API domain for the guest Matrix instance";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 8108;
        description = "Internal port for the guest Matrix server";
      };

      stateDirectory = lib.mkOption {
        type = lib.types.str;
        default = "matrix-conduit-guest";
        description = "State directory for the guest Matrix instance";
      };

      settings = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Additional settings for the guest Matrix instance";
      };

      user = lib.mkOption {
        type = lib.types.nonEmptyStr;
        default = guestDefaultUser;
        description = "User that the guest Tuwunel instance runs as";
      };

      group = lib.mkOption {
        type = lib.types.nonEmptyStr;
        default = guestDefaultGroup;
        description = "Group that the guest Tuwunel instance runs as";
      };

      extraEnvironment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Extra environment variables for the guest Tuwunel instance";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.services.caddy.enable;
          message = "Caddy has to be enabled for tuwunel Matrix server to work";
        }
      ];

      services.matrix-tuwunel = {
        enable = true;
        inherit (cfg) package;
        inherit stateDirectory;

        # https://matrix-construct.github.io/tuwunel/configuration/examples.html#example-configuration
        settings = {
          global = lib.mkMerge [
            {
              server_name = cfg.mainDomain;
              trusted_servers = [ "matrix.org" ];

              address = [ "127.0.0.1" ];
              port = [ cfg.port ];

              max_request_size = 20000000;
              zstd_compression = false;
              gzip_compression = false;
              brotli_compression = false;

              ip_range_denylist = [
                "127.0.0.0/8"
                "10.0.0.0/8"
                "172.16.0.0/12"
                "192.168.0.0/16"
                "100.64.0.0/10"
                "192.0.0.0/24"
                "169.254.0.0/16"
                "192.88.99.0/24"
                "198.18.0.0/15"
                "192.0.2.0/24"
                "198.51.100.0/24"
                "203.0.113.0/24"
                "224.0.0.0/4"
                "::1/128"
                "fe80::/10"
                "fc00::/7"
                "2001:db8::/32"
                "ff00::/8"
                "fec0::/10"
              ];

              allow_legacy_media = false;
              allow_guest_registration = false;
              log_guest_registrations = false;
              allow_guests_auto_join_rooms = false;
              allow_registration = true;
              registration_token = secrets.tuwunel.registrationToken;
              allow_federation = true;
              allow_public_room_directory_over_federation = false;
              allow_public_room_directory_without_auth = false;
              lockdown_public_room_directory = false;
              allow_device_name_federation = false;
              url_preview_domain_contains_allowlist = [ ];
              url_preview_domain_explicit_allowlist = [
                "x.com"
                "fixupx.com"
                "twitterfx.com"
                "t.me"
                "youtube.com"
                "github.com"
                "reddit.com"
                "pkg.go.dev"
                "go.dev"
                "matrix.org"
                "spec.matrix.org"
                "steamcommunity.com"
                "store.steampowered.com"
                "youtu.be"
                "youtube.com"
                "www.linux.org.ru"
                "www.opennet.ru"
                "habr.com"
              ];
              url_preview_url_contains_allowlist = [ ];
              url_preview_domain_explicit_denylist = [ ];
              url_preview_max_spider_size = 384000;
              url_preview_check_root_domain = false;
              allow_profile_lookup_federation_requests = true;

              log = "info";
              new_user_displayname_suffix = "";

              # Memory optimizations
              cache_capacity_modifier = 1.2;
              db_cache_capacity_mb = 64.0;
              db_write_buffer_capacity_mb = 24.0;
              dns_cache_entries = 4096;
              stream_width_scale = 0.5;
              stream_amplification = 256;
              stream_width_default = 16;
              db_pool_workers = 8;

              allow_local_presence = true;
              allow_incoming_presence = false;
              allow_outgoing_presence = false;

              identity_provider = [
                {
                  brand = "keycloak";
                  client_id = "tuwunel";
                  client_secret = secrets.tuwunel.oidcClientSecret;
                  issuer_url = "https://${config.cumserver.keycloak.domain}/realms/meow";
                  discovery_url = "https://${config.cumserver.keycloak.domain}/realms/meow/.well-known/openid-configuration";
                  callback_url = "https://${cfg.domain}/_matrix/client/unstable/login/sso/callback/tuwunel";

                  # optional:
                  # default = true;
                  # name = "Company SSO";
                  # scope = [ "openid" "profile" "email" ];
                  # userid_claims = [ "sub" ];
                  # discovery = true;
                }
              ];

              # Well-known configuration for client discovery and Element Call (MSC4143)
              well_known = {
                client = "https://${cfg.domain}";
                server = "${cfg.domain}:443";
                rtc_transports = lib.optionals config.cumserver.element-call.enable [
                  {
                    type = "livekit";
                    livekit_service_url = "https://${config.cumserver.element-call.domain}/livekit/jwt";
                  }
                ];
              };
            }
            cfg.settings
          ];
        };
      };

      services.caddy.virtualHosts = {
        "${config.cumserver.tuwunel.mainDomain}" = {
          serverAliases = [ "www.${config.cumserver.tuwunel.mainDomain}" ];
          extraConfig = ''
            root * ${inputs'.sleroq-link.packages.default}
            encode zstd gzip

            handle /.well-known/* {
              reverse_proxy 127.0.0.1:${toString config.cumserver.tuwunel.port}
            }

            file_server
          '';
        };

        "element.${config.cumserver.tuwunel.clientDomain}" = {
          extraConfig = ''
            root * ${
              pkgs.element-web.override {
                conf = {
                  showLabsSettings = true;
                  default_server_config."m.homeserver" = {
                    base_url = "https://${config.cumserver.tuwunel.domain}";
                    server_name = config.cumserver.tuwunel.mainDomain;
                  };
                } // lib.optionalAttrs config.cumserver.element-call.enable {
                  element_call = {
                    url = "https://${config.cumserver.element-call.domain}";
                    guest_spa_url = "https://${config.cumserver.element-call.guestDomain}";
                  };
                };
              }
            }
            file_server
            encode zstd gzip
          '';
        };

        "cinny.${config.cumserver.tuwunel.clientDomain}" = {
          extraConfig = ''
            root * ${pkgs.cinny}
            encode zstd gzip

            handle /config.json {
              header Content-Type application/json
              respond `${
                builtins.toJSON {
                  allowCustomHomeservers = true;
                  homeserverList = [ config.cumserver.tuwunel.mainDomain ];
                  defaultHomeserver = 0;
                  hashRouter = {
                    enabled = false;
                    basename = "/";
                  };
                  featuredCommunities = {
                    openAsDefault = false;
                    servers = [
                      config.cumserver.tuwunel.mainDomain
                      "matrix.org"
                    ];
                    spaces = [ "!FwtFmFqM4bwuaWtRKB:sleroq.link" ];
                    rooms = [ ];
                  };
                }
              }` 200
            }

            handle {
              try_files {path} /index.html
              file_server
            }
          '';
        };

        "${config.cumserver.tuwunel.domain}" = {
          extraConfig = ''
            handle /_matrix/* {
              reverse_proxy 127.0.0.1:${toString config.cumserver.tuwunel.port}
            }
          '';
        };
      } // lib.optionalAttrs cfg.guest.enable {
        "${cfg.guest.mainDomain}" = {
          extraConfig = ''
            handle /.well-known/* {
              reverse_proxy 127.0.0.1:${toString cfg.guest.port}
            }

            file_server
          '';
        };

        "${cfg.guest.domain}" = {
          extraConfig = ''
            handle /_matrix/* {
              reverse_proxy 127.0.0.1:${toString cfg.guest.port}
            }
          '';
        };
      };
    })

    (lib.mkIf (cfg.enable && cfg.guest.enable) (
      let
        guestConfigFile = tomlFormat.generate "tuwunel-guest.toml" {
          global = lib.recursiveUpdate
            {
              server_name = cfg.guest.mainDomain;
              trusted_servers = [ "matrix.org" "m.sleroq.link" ];

              address = [ "127.0.0.1" ];
              port = [ cfg.guest.port ];
              database_path = "/var/lib/${cfg.guest.stateDirectory}/";

              max_request_size = 200000;
              zstd_compression = false;
              gzip_compression = false;
              brotli_compression = false;

              ip_range_denylist = [
                "127.0.0.0/8"
                "10.0.0.0/8"
                "172.16.0.0/12"
                "192.168.0.0/16"
                "100.64.0.0/10"
                "192.0.0.0/24"
                "169.254.0.0/16"
                "192.88.99.0/24"
                "198.18.0.0/15"
                "192.0.2.0/24"
                "198.51.100.0/24"
                "203.0.113.0/24"
                "224.0.0.0/4"
                "::1/128"
                "fe80::/10"
                "fc00::/7"
                "2001:db8::/32"
                "ff00::/8"
                "fec0::/10"
              ];

              allow_legacy_media = false;
              allow_guest_registration = true;
              log_guest_registrations = true;
              allow_guests_auto_join_rooms = true;
              allow_registration = false;
              allow_federation = false;
              allow_public_room_directory_over_federation = false;
              allow_public_room_directory_without_auth = false;
              lockdown_public_room_directory = true;
              allow_device_name_federation = false;
              allow_profile_lookup_federation_requests = true;

              log = "info";
              new_user_displayname_suffix = "";

              allow_local_presence = false;
              allow_incoming_presence = false;
              allow_outgoing_presence = false;

              well_known = {
                client = "https://${cfg.guest.domain}";
                server = "${cfg.guest.domain}:443";
                rtc_transports = lib.optionals config.cumserver.element-call.enable [
                  {
                    type = "livekit";
                    livekit_service_url = "https://${config.cumserver.element-call.domain}/livekit/jwt";
                  }
                ];
              };
            }
            cfg.guest.settings;
        };
      in
      {
        users.users = lib.mkIf (cfg.guest.user == guestDefaultUser) {
          ${guestDefaultUser} = {
            group = cfg.guest.group;
            home = "/var/lib/${cfg.guest.stateDirectory}/";
            isSystemUser = true;
          };
        };

        users.groups = lib.mkIf (cfg.guest.group == guestDefaultGroup) {
          ${guestDefaultGroup} = { };
        };

        systemd.services.tuwunel-guest = {
          description = "Tuwunel Matrix Server (guest)";
          documentation = [ "https://matrix-construct.github.io/tuwunel/" ];
          wantedBy = [ "multi-user.target" ];
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];
          environment = lib.mkMerge [
            { TUWUNEL_CONFIG = guestConfigFile; }
            cfg.guest.extraEnvironment
          ];
          startLimitBurst = 5;
          startLimitIntervalSec = 60;
          serviceConfig = {
            Type = "notify";

            DynamicUser = true;
            User = cfg.guest.user;
            Group = cfg.guest.group;

            DevicePolicy = "closed";
            LockPersonality = true;
            MemoryDenyWriteExecute = true;
            NoNewPrivileges = true;
            ProtectClock = true;
            ProtectControlGroups = true;
            ProtectHome = true;
            ProtectHostname = true;
            ProtectKernelLogs = true;
            ProtectKernelModules = true;
            ProtectKernelTunables = true;
            ProtectProc = "invisible";
            ProtectSystem = "strict";
            PrivateDevices = true;
            PrivateMounts = true;
            PrivateTmp = true;
            PrivateUsers = true;
            PrivateIPC = true;
            RemoveIPC = true;
            RestrictAddressFamilies = [
              "AF_INET"
              "AF_INET6"
              "AF_UNIX"
            ];
            RestrictNamespaces = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            SystemCallArchitectures = "native";
            SystemCallFilter = [
              "@system-service @resources"
              "~@clock @debug @module @mount @reboot @swap @cpu-emulation @obsolete @timer @chown @setuid @privileged @keyring @ipc"
            ];
            SystemCallErrorNumber = "EPERM";

            StateDirectory = cfg.guest.stateDirectory;
            StateDirectoryMode = "0700";
            RuntimeDirectory = "tuwunel-guest";
            RuntimeDirectoryMode = "0750";

            ExecStart = lib.getExe cfg.package;
            Restart = "on-failure";
            RestartSec = 10;
          };
        };
      }
    ))

    (lib.mkIf (cfg.enable && cfg.backup.enable) {
      services.restic.backups.tuwunel = {
        user = "root";
        repository = "s3:https://b9b008414ac92325dff304821d2a0a2c.eu.r2.cloudflarestorage.com/bots-backups";
        passwordFile = config.age.secrets.resticBackupsPassword.path;
        environmentFile = config.age.secrets.resticS3Keys.path;
        initialize = true;
        paths = [ "/var/lib/private/${stateDirectory}" ];
        pruneOpts = [ "--keep-weekly 1" ];
        exclude = [
          "media"
          "**/*.log"
        ];
        timerConfig = {
          OnCalendar = "weekly";
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
        backupPrepareCommand = "systemctl stop tuwunel.service";
        backupCleanupCommand = "systemctl start tuwunel.service";
      };
    })
  ];
}
