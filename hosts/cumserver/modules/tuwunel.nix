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
in
{
  options.cumserver.tuwunel = {
    enable = lib.mkEnableOption "Matrix edge services";

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

    backend = lib.mkOption {
      type = lib.types.str;
      default = "div:8008";
      description = "Tuwunel backend reachable over Tailscale";
    };

    turn = {
      enable = lib.mkEnableOption "Coturn for Matrix calls" // {
        default = true;
      };

      tls = {
        certFile = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/acme/${cfg.turn.domain}/fullchain.pem";
          description = "Path to Coturn TLS certificate file";
        };

        keyFile = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/acme/${cfg.turn.domain}/key.pem";
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

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.caddy.enable;
        message = "Caddy has to be enabled for the Matrix edge to work";
      }
      {
        assertion = (!cfg.turn.enable) || (cfg.turn.secret != "");
        message = "cumserver.tuwunel.turn.secret must be set when TURN is enabled";
      }
      {
        assertion = (!cfg.turn.enable) || (cfg.turn.tls.certFile != "" && cfg.turn.tls.keyFile != "");
        message = "cumserver.tuwunel.turn.tls.certFile and keyFile must be set when TURN is enabled";
      }
    ];

    security.acme = lib.mkIf cfg.turn.enable {
      acceptTerms = true;
      defaults.email = config.services.caddy.email;
      certs."${cfg.turn.domain}" = {
        webroot = "/var/lib/acme/acme-challenge";
      };
    };

    services.caddy.virtualHosts = {
      "${config.cumserver.tuwunel.mainDomain}" = {
        serverAliases = [ "www.${config.cumserver.tuwunel.mainDomain}" ];
        extraConfig = ''
          root * ${inputs'.sleroq-link.packages.default}
          encode zstd gzip

          handle /.well-known/* {
            reverse_proxy ${cfg.backend}
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
                jitsi = {
                  preferred_domain = "meet.jit.si";
                };
                room_directory = {
                  servers = [
                    config.cumserver.tuwunel.mainDomain
                    "matrix.org"
                    "mozilla.org"
                    "unredacted.org"
                  ];
                };
                setting_defaults = {
                  "MessageComposerInput.showStickersButton" = false;
                };
                features = {
                  feature_video_rooms = true;
                  feature_element_call_video_rooms = true;
                  feature_group_calls = true;
                  feature_notifications = true;
                  feature_ask_to_join = true;
                  feature_new_room_list = true;
                  feature_share_history_on_invite = true;
                  feature_pinning = true;
                  feature_jump_to_date = true;
                  feature_mjolnir = true;
                  feature_bridge_state = true;
                  feature_custom_themes = true;
                };
                default_server_config = {
                  "m.homeserver" = {
                    base_url = "https://${config.cumserver.tuwunel.domain}";
                    server_name = config.cumserver.tuwunel.mainDomain;
                  };
                  "m.identity_server" = {
                    base_url = "https://vector.im";
                  };
                };
              }
              // lib.optionalAttrs config.cumserver.element-call.enable {
                element_call = {
                  url = "https://${config.cumserver.element-call.domain}";
                  use_exclusively = true;
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
                    "mozilla.org"
                    "unredacted.org"
                  ];
                  spaces = [
                    "!xPWsQQHAsLQiJzm1JJPqynB-gAq4ycN6cY3GvkjQSas:sleroq.link"
                    "!brXHJeAtqliwNGqHQx:lossy.network"
                    "#science-space:matrix.org"
                    "#community:matrix.org"
                    "#cinny-space:matrix.org"
                    "!_G-Utf3nOR3_6J3sbvycpRkssI6qlK8pnuBF7OXpJYA:sleroq.link"
                  ];
                  rooms = [
                    "#cinny:matrix.org"
                    "#gentoo:matrix.org"
                  ];
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
            reverse_proxy ${cfg.backend}
          }
        '';
      };

      "${cfg.turn.domain}" = {
        extraConfig = ''
          handle /.well-known/acme-challenge/* {
            root * /var/lib/acme/acme-challenge
            file_server
          }

          respond ""
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
        cert=${cfg.turn.tls.certFile}
        pkey=${cfg.turn.tls.keyFile}
        tls-listening-port=5349
      '';
    };

    systemd.services.coturn.serviceConfig.SupplementaryGroups = lib.optionals cfg.turn.enable [
      "acme"
    ];

    networking.firewall = lib.mkIf cfg.turn.enable {
      allowedTCPPorts = [ 5349 ];
      allowedUDPPorts = [ 5349 ];
      allowedUDPPortRanges = [
        {
          from = cfg.turn.minPort;
          to = cfg.turn.maxPort;
        }
      ];
    };
  };
}
