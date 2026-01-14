{ config, inputs', lib, secrets, pkgs, ... }:
let
  cfg = config.cumserver.tuwunel;
  stateDirectory = "matrix-conduit";
in
{
  options.cumserver.tuwunel = {
    enable = lib.mkEnableOption "Tuwunel Matrix server";

    backup.enable = lib.mkEnableOption "backups" // { default = true; };

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
      default = {};
      description = "Additional settings for the Matrix server";
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
              url_preview_domain_contains_allowlist = [];
              url_preview_domain_explicit_allowlist = [];
              url_preview_url_contains_allowlist = [];
              url_preview_domain_explicit_denylist = [];
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

              allow_local_presence = false;
              allow_incoming_presence = false;
              allow_outgoing_presence = false;
            }
            cfg.settings
          ];

          # Well-known configuration for client discovery and Element Call (MSC4143)
          well_known = {
            client = "https://${cfg.domain}";
            server = "${cfg.domain}:443";
            rtc_transports = [
              {
                type = "livekit";
                livekit_service_url = "https://call.cum.army/livekit/jwt";
              }
            ];
          };
        };
      };

      age.secrets.cf-fullchain = {
        owner = "caddy";
        group = "caddy";
        file = ../secrets/cf-fullchain.pem;
      };
      age.secrets.cf-privkey = {
        owner = "caddy";
        group = "caddy";
        file = ../secrets/cf-privkey.pem;
      };

      services.caddy.virtualHosts = {
          "${config.cumserver.tuwunel.mainDomain}" = {
            serverAliases = [ "www.${config.cumserver.tuwunel.mainDomain}" ];
            extraConfig = ''
              tls ${config.age.secrets.cf-fullchain.path} ${config.age.secrets.cf-privkey.path}

              root * ${inputs'.sleroq-link.packages.default}
              file_server
              encode zstd gzip

              handle_path /.well-known/matrix/server {
                  header Access-Control-Allow-Origin *
                  respond `{"m.server": "${config.cumserver.tuwunel.domain}:443"}` 200
              }

              handle_path /.well-known/matrix/client {
                  header Access-Control-Allow-Origin *
                  header Content-Type application/json
                  respond `${builtins.toJSON {
                    "m.homeserver" = {
                      base_url = "https://${config.cumserver.tuwunel.domain}";
                    };
                    "org.matrix.msc4143.rtc_foci" = [
                      {
                        type = "livekit";
                        livekit_service_url = "https://call.cum.army/livekit/jwt";
                      }
                    ];
                  }}` 200
              }
            '';
          };

          "${config.cumserver.tuwunel.domain}" = {
            extraConfig = ''
              tls ${config.age.secrets.cf-fullchain.path} ${config.age.secrets.cf-privkey.path}

              handle /_matrix/* {
                reverse_proxy 127.0.0.1:${toString config.cumserver.tuwunel.port}
              }
          '';
        };
      };
    })

    (lib.mkIf (cfg.enable && cfg.backup.enable) {
      services.restic.backups.tuwunel = {
        user = "root";
        repository = "s3:https://b9b008414ac92325dff304821d2a0a2c.eu.r2.cloudflarestorage.com/bots-backups";
        passwordFile = config.age.secrets.resticBackupsPassword.path;
        environmentFile = config.age.secrets.resticS3Keys.path;
        initialize = true;
        paths = [ "/var/lib/private/${stateDirectory}" ];
        pruneOpts = [ "--keep-weekly 1" ];
        exclude = [ "media" "**/*.log" ];
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
