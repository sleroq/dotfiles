{ config, lib, ... }:

let
  cfg = config.services.matrix-tuwunel;
  credentialDirectory = "/run/credentials/tuwunel.service";
in
{
  options.services.matrix-tuwunel = {
    mainDomain = lib.mkOption {
      type = lib.types.str;
      default = "sleroq.link";
      description = "Matrix server name";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "m.sleroq.link";
      description = "Public Matrix homeserver domain";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address on which Tuwunel listens";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8008;
      description = "Port on which Tuwunel listens";
    };

    registrationTokenFile = lib.mkOption {
      type = lib.types.path;
      description = "File containing Tuwunel registration tokens";
    };

    turn = {
      enable = lib.mkEnableOption "TURN credentials" // {
        default = true;
      };

      domain = lib.mkOption {
        type = lib.types.str;
        default = "turn.${cfg.mainDomain}";
        description = "Domain of the external TURN server";
      };

      secretFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "File containing the TURN shared secret";
      };
    };

    elementCallUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "External Element Call LiveKit URL";
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Additional Tuwunel global settings";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.turn.enable || cfg.turn.secretFile != null;
        message = "services.matrix-tuwunel.turn.secretFile must be set when TURN is enabled";
      }
    ];

    services.matrix-tuwunel = {
      stateDirectory = "matrix-conduit";

      # https://matrix-construct.github.io/tuwunel/configuration/examples.html
      settings.global = lib.mkMerge [
        {
          server_name = cfg.mainDomain;
          trusted_servers = [ "matrix.org" ];

          address = [ cfg.listenAddress ];
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
          registration_token_file = "${credentialDirectory}/registration-token";
          allow_federation = true;
          allow_public_room_directory_over_federation = false;
          allow_public_room_directory_without_auth = false;
          lockdown_public_room_directory = false;
          allow_device_name_federation = false;
          default_room_version = "12";
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
          allow_inbound_profile_lookup_federation_requests = true;

          turn_uris = lib.optionals cfg.turn.enable [
            "turns:${cfg.turn.domain}:5349?transport=tcp"
          ];
          turn_secret_file = lib.mkIf cfg.turn.enable "${credentialDirectory}/turn-secret";

          log = "info";
          new_user_displayname_suffix = "";

          # Keep federation and database maintenance from saturating this host.
          # sender_timeout also controls request duration, so increasing it to
          # force hourly retries would leave federation requests stalled longer.
          sender_retry_grace = 0;
          fetch_fanout_max_width = 1;
          rocksdb_parallelism_threads = 2;
          rocksdb_compaction_prio_idle = true;

          stream_width_scale = 0.5;
          # cache_capacity_modifier = 1.2;
          # db_cache_capacity_mb = 64.0;
          # db_write_buffer_capacity_mb = 24.0;
          # dns_cache_entries = 4096;
          # stream_width_scale = 0.5;
          # stream_amplification = 256;
          # stream_width_default = 16;
          # db_pool_workers = 8;

          allow_local_presence = true;
          allow_incoming_presence = true;
          allow_outgoing_presence = true;
          presence_timeout_remote_users = false;

          well_known = {
            client = "https://${cfg.domain}";
            server = "${cfg.domain}:443";
            rtc_transports = lib.optionals (cfg.elementCallUrl != null) [
              {
                type = "livekit";
                livekit_service_url = cfg.elementCallUrl;
              }
            ];
          };
        }
        cfg.extraSettings
      ];
    };

    systemd.services.tuwunel.serviceConfig.LoadCredential = [
      "registration-token:${cfg.registrationTokenFile}"
    ]
    ++ lib.optionals cfg.turn.enable [
      "turn-secret:${cfg.turn.secretFile}"
    ];
  };
}
