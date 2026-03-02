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
  caddyCertDir = "/var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/${cfg.turn.domain}";
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

    turn = {
      enable = lib.mkEnableOption "Coturn for Matrix calls" // {
        default = true;
      };

      tls = {
        enable = lib.mkEnableOption "TURN over TLS (turns://)" // {
          default = true;
        };

        certFile = lib.mkOption {
          type = lib.types.str;
          default = "${caddyCertDir}/${cfg.turn.domain}.crt";
          description = "Path to Coturn TLS certificate file";
        };

        keyFile = lib.mkOption {
          type = lib.types.str;
          default = "${caddyCertDir}/${cfg.turn.domain}.key";
          description = "Path to Coturn TLS private key file";
        };
      };

      domain = lib.mkOption {
        type = lib.types.str;
        default = "turn.${cfg.mainDomain}";
        description = "Domain used by Matrix clients to reach TURN";
      };

      secret = lib.mkOption {
        type = lib.types.str;
        default = lib.attrByPath [ "tuwunel" "turnSecret" ] "" secrets;
        description = "Coturn static auth secret used by Tuwunel and LiveKit";
      };

      minPort = lib.mkOption {
        type = lib.types.port;
        default = 50201;
        description = "Coturn relay UDP range start";
      };

      maxPort = lib.mkOption {
        type = lib.types.port;
        default = 65535;
        description = "Coturn relay UDP range end";
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
        {
          assertion = (!cfg.turn.enable) || (cfg.turn.secret != "");
          message = "cumserver.tuwunel.turn.secret must be set when TURN is enabled";
        }
        {
          assertion =
            (!cfg.turn.enable)
            || (!cfg.turn.tls.enable)
            || (cfg.turn.tls.certFile != "" && cfg.turn.tls.keyFile != "");
          message = "cumserver.tuwunel.turn.tls.certFile and keyFile must be set when TURN TLS is enabled";
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

              turn_uris =
                lib.optionals cfg.turn.enable [
                  "turn:${cfg.turn.domain}:3478?transport=udp"
                  "turn:${cfg.turn.domain}:3478?transport=tcp"
                ]
                ++ lib.optionals (cfg.turn.enable && cfg.turn.tls.enable) [
                  "turns:${cfg.turn.domain}:5349?transport=tcp"
                ];
              turn_secret = lib.optionalString cfg.turn.enable cfg.turn.secret;

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
                    livekit_service_url = "https://${config.cumserver.element-call.domain}";
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
                }
                // lib.optionalAttrs config.cumserver.element-call.enable {
                  element_call = {
                    url = "https://${config.cumserver.element-call.domain}";
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
      };

      services.coturn = lib.mkIf cfg.turn.enable {
        enable = true;
        realm = cfg.mainDomain;
        use-auth-secret = true;
        no-cli = true;
        min-port = cfg.turn.minPort;
        max-port = cfg.turn.maxPort;
        extraConfig = ''
          static-auth-secret=${cfg.turn.secret}
          ${lib.optionalString cfg.turn.tls.enable ''
            cert=${cfg.turn.tls.certFile}
            pkey=${cfg.turn.tls.keyFile}
            tls-listening-port=5349
          ''}
        '';
      };

      systemd.services.coturn.serviceConfig.SupplementaryGroups = lib.optionals cfg.turn.tls.enable [
        "caddy"
      ];

      networking.firewall = lib.mkIf cfg.turn.enable {
        allowedTCPPorts = [ 3478 ] ++ lib.optionals cfg.turn.tls.enable [ 5349 ];
        allowedUDPPorts = [ 3478 ] ++ lib.optionals cfg.turn.tls.enable [ 5349 ];
        allowedUDPPortRanges = [
          {
            from = cfg.turn.minPort;
            to = cfg.turn.maxPort;
          }
        ];
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
