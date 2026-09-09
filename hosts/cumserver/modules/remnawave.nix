{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cumserver.remnawave;

  remnawaveCertSync = pkgs.writeShellApplication {
    name = "remnawave-cert-sync";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      gnugrep
      gnutar
      jq
      openssh
      openssl
    ];
    text = ''
      set -euo pipefail
      umask 077

      workdir=$(mktemp -d "$RUNTIME_DIRECTORY/work.XXXXXX")
      trap 'rm -rf "$workdir"' EXIT

      printf '%s\n' '45.144.51.68 ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBPmGGuGeW5CmB44ephJVAsEwHqZzj6DS12VCnzGNgYVUSvt4StxDroJ/ishVC/PWXFapJ5iVW2wp8TV3jiBFPE4=' > "$workdir/known_hosts"
      ssh \
        -i ${config.age.secrets.remnawaveWarsawCertSyncKey.path} \
        -o BatchMode=yes \
        -o HostKeyAlgorithms=ecdsa-sha2-nistp256 \
        -o IdentitiesOnly=yes \
        -o UserKnownHostsFile="$workdir/known_hosts" \
        klj@45.144.51.68 > "$workdir/warsaw.tar"
      tar -xf "$workdir/warsaw.tar" -C "$workdir"

      printf 'header = "Authorization: Bearer %s"\n' "$(cat ${config.age.secrets.remnawaveToken.path})" > "$workdir/curl.conf"
      curl --fail --silent --show-error --config "$workdir/curl.conf" \
        https://${cfg.domain}/api/config-profiles > "$workdir/profiles.json"
      curl --fail --silent --show-error --config "$workdir/curl.conf" \
        https://${cfg.domain}/api/nodes > "$workdir/nodes.json"

      sync_profile() {
        profile_name=$1
        inbound_tag=$2
        node_name=$3
        certificate=$4
        key=$5
        listen_port=''${6:-}

        jq --arg profile "$profile_name" --arg tag "$inbound_tag" -r '
          .response.configProfiles[] | select(.name == $profile) |
          .config.inbounds[] | select(.tag == $tag) |
          .streamSettings.tlsSettings.certificates[0].certificate |
          if type == "array" then join("\n") else . end
        ' "$workdir/profiles.json" > "$workdir/current.crt"

        current_fingerprint=$(openssl x509 -in "$workdir/current.crt" -noout -fingerprint -sha256)
        next_fingerprint=$(openssl x509 -in "$certificate" -noout -fingerprint -sha256)
        current_port=$(jq --arg profile "$profile_name" --arg tag "$inbound_tag" -r '
          .response.configProfiles[] | select(.name == $profile) |
          .config.inbounds[] | select(.tag == $tag) | .port
        ' "$workdir/profiles.json")
        if [ "$current_fingerprint" = "$next_fingerprint" ] \
          && { [ -z "$listen_port" ] || [ "$current_port" = "$listen_port" ]; }; then
          return
        fi

        jq \
          --arg profile "$profile_name" \
          --arg tag "$inbound_tag" \
          --argjson port "''${listen_port:-null}" \
          --rawfile certificate "$certificate" \
          --rawfile key "$key" '
          .response.configProfiles[] | select(.name == $profile) |
          .config.inbounds |= map(
            if .tag == $tag then
              (if $port == null then . else .port = $port end) |
              .streamSettings.tlsSettings.certificates = [{
                certificate: ($certificate | split("\n") | map(select(length > 0))),
                key: ($key | split("\n") | map(select(length > 0)))
              }]
            else . end
          ) |
          {uuid, name, config}
        ' "$workdir/profiles.json" > "$workdir/profile-update.json"

        curl --fail --silent --show-error --config "$workdir/curl.conf" \
          --request PATCH \
          --header 'Content-Type: application/json' \
          --data-binary "@$workdir/profile-update.json" \
          https://${cfg.domain}/api/config-profiles/ > /dev/null

        node_uuid=$(jq --arg node "$node_name" -r '.response[] | select(.name == $node) | .uuid' "$workdir/nodes.json")
        printf '%s\n' '{"forceRestart":true}' > "$workdir/restart.json"
        curl --fail --silent --show-error --config "$workdir/curl.conf" \
          --request POST \
          --header 'Content-Type: application/json' \
          --data-binary "@$workdir/restart.json" \
          "https://${cfg.domain}/api/nodes/$node_uuid/actions/restart" > /dev/null
      }

      caddy_certs=/var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory
      sync_profile 'Remnawave Cumserver' HYSTERIA2_CUMSERVER Cumserver \
        "$caddy_certs/edge.cum.army/edge.cum.army.crt" \
        "$caddy_certs/edge.cum.army/edge.cum.army.key" \
        ${toString cfg.node.clientUdpPort}
      sync_profile div-private DIV_HYSTERIA2 div \
        "$caddy_certs/div.cum.army/div.cum.army.crt" \
        "$caddy_certs/div.cum.army/div.cum.army.key"
      sync_profile 'Remnawave Warsaw' HYSTERIA2_WARSAW Warsaw \
        "$workdir/fullchain.pem" "$workdir/privkey.pem"
    '';
  };
in
{
  options.cumserver.remnawave = {
    enable = lib.mkEnableOption "Remnawave proxy management panel";

    backup.enable = lib.mkEnableOption "backups" // {
      default = true;
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/remnawave/backend:3.3.2";
      description = "Docker image to use for Remnawave backend";
    };

    postgresImage = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/library/postgres:17.9";
      description = "Docker image to use for Remnawave PostgreSQL";
    };

    redisImage = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/valkey/valkey:9.0.3-alpine";
      description = "Docker image to use for Remnawave Redis/Valkey";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "uwu.sleroq.link";
      description = "Domain name for Remnawave panel";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Internal port for Remnawave panel";
    };

    metricsPort = lib.mkOption {
      type = lib.types.port;
      default = 3001;
      description = "Internal port for Remnawave metrics endpoint";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/remnawave";
      description = "Data directory for Remnawave state";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Environment file containing Remnawave backend and PostgreSQL variables";
    };

    metricsUsername = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "Username for the Remnawave metrics endpoint";
    };

    metricsPasswordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "File containing the Remnawave metrics password";
    };

    extraOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional options to pass to Remnawave containers";
    };

    subscriptionPage = {
      enable = lib.mkEnableOption "Remnawave subscription page";

      image = lib.mkOption {
        type = lib.types.str;
        default = "docker.io/remnawave/subscription-page:8.0.0";
        description = "Docker image to use for Remnawave subscription page";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 3010;
        description = "Internal port for Remnawave subscription page";
      };

      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional domain for Remnawave subscription page";
      };

      environmentFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Optional environment file for the subscription page";
      };
    };

    node = {
      enable = lib.mkEnableOption "local Remnawave node";

      image = lib.mkOption {
        type = lib.types.str;
        default = "docker.io/remnawave/node:2.8.0";
        description = "Docker image to use for the local Remnawave node";
      };

      environmentFile = lib.mkOption {
        type = lib.types.path;
        description = "Environment file containing NODE_PORT and SECRET_KEY";
      };

      managementPort = lib.mkOption {
        type = lib.types.port;
        default = 62053;
        description = "Panel-only Remnawave node management port";
      };

      clientTcpPort = lib.mkOption {
        type = lib.types.port;
        default = 2080;
        description = "Public VLESS TCP port";
      };

      clientUdpPort = lib.mkOption {
        type = lib.types.port;
        default = 8443;
        description = "Public Hysteria2 UDP port";
      };

      logDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/log/remnanode";
        description = "Persistent Remnawave node log directory";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.virtualisation.oci-containers.backend != null;
          message = "OCI containers backend must be configured for Remnawave to work";
        }
        {
          assertion = config.services.caddy.enable;
          message = "Caddy has to be enabled for Remnawave to work";
        }
        {
          assertion = cfg.environmentFile != null;
          message = "cumserver.remnawave.environmentFile must be set and contain required Remnawave env vars";
        }
        {
          assertion = cfg.subscriptionPage.enable || cfg.subscriptionPage.domain == null;
          message = "cumserver.remnawave.subscriptionPage.domain requires cumserver.remnawave.subscriptionPage.enable = true";
        }
        {
          assertion = !config.cumserver.monitoring.enable || cfg.metricsPasswordFile != null;
          message = "cumserver.remnawave.metricsPasswordFile must be set when monitoring is enabled";
        }
        {
          assertion = !cfg.node.enable || cfg.node.environmentFile != null;
          message = "cumserver.remnawave.node.environmentFile must be set when the local node is enabled";
        }
      ];

      virtualisation.oci-containers.containers = {
        remnawave-db = {
          autoStart = true;
          image = cfg.postgresImage;
          environmentFiles = [ cfg.environmentFile ];
          environment.TZ = "UTC";
          extraOptions = cfg.extraOptions ++ [ "--shm-size=512m" ];
          volumes = [
            "${cfg.dataDir}/postgres17:/var/lib/postgresql/data"
          ];
        };

        remnawave-redis = {
          autoStart = true;
          image = cfg.redisImage;
          cmd = [
            "valkey-server"
            "--save"
            ""
            "--appendonly"
            "no"
            "--maxmemory-policy"
            "noeviction"
            "--loglevel"
            "warning"
            "--unixsocket"
            "/var/run/valkey/valkey.sock"
            "--unixsocketperm"
            "777"
            "--port"
            "0"
          ];
          extraOptions = cfg.extraOptions;
          volumes = [ "remnawave-valkey-socket:/var/run/valkey" ];
        };

        remnawave = {
          autoStart = true;
          image = cfg.image;
          dependsOn = [
            "remnawave-db"
            "remnawave-redis"
          ];
          environmentFiles = [ cfg.environmentFile ];
          environment = {
            APP_PORT = toString cfg.port;
            METRICS_PORT = toString cfg.metricsPort;
          };
          ports = [
            "127.0.0.1:${toString cfg.port}:${toString cfg.port}"
            "127.0.0.1:${toString cfg.metricsPort}:${toString cfg.metricsPort}"
          ];
          extraOptions = cfg.extraOptions;
          volumes = [ "remnawave-valkey-socket:/var/run/valkey" ];
        };
      }
      // lib.optionalAttrs cfg.subscriptionPage.enable {
        remnawave-subscription-page = {
          autoStart = true;
          image = cfg.subscriptionPage.image;
          dependsOn = [ "remnawave" ];
          environmentFiles = lib.optional (
            cfg.subscriptionPage.environmentFile != null
          ) cfg.subscriptionPage.environmentFile;
          environment = {
            APP_PORT = toString cfg.subscriptionPage.port;
            REMNAWAVE_PANEL_URL = "http://remnawave:${toString cfg.port}";
          };
          ports = [
            "127.0.0.1:${toString cfg.subscriptionPage.port}:${toString cfg.subscriptionPage.port}"
          ];
          extraOptions = cfg.extraOptions;
        };
      }
      // lib.optionalAttrs cfg.node.enable {
        remnanode = {
          autoStart = true;
          image = cfg.node.image;
          dependsOn = [ "remnawave" ];
          environmentFiles = [ cfg.node.environmentFile ];
          extraOptions = cfg.extraOptions ++ [
            "--network=host"
            "--cap-add=NET_ADMIN"
            "--ulimit=nofile=1048576:1048576"
          ];
          volumes = [ "${cfg.node.logDir}:/var/log/remnanode" ];
        };
      };

      services.caddy.virtualHosts = {
        ${cfg.domain} = {
          extraConfig = ''
            reverse_proxy 127.0.0.1:${toString cfg.port}
            encode zstd gzip

            header {
              X-Content-Type-Options nosniff
              X-Frame-Options SAMEORIGIN
              X-XSS-Protection "1; mode=block"
              X-Real-IP {remote_addr}
              X-Forwarded-For {remote_addr}
              X-Forwarded-Host {host}
            }
          '';
        };
      }
      // lib.optionalAttrs (cfg.subscriptionPage.enable && cfg.subscriptionPage.domain != null) {
        ${cfg.subscriptionPage.domain} = {
          extraConfig = ''
            reverse_proxy 127.0.0.1:${toString cfg.subscriptionPage.port}
            encode zstd gzip

            header {
              X-Content-Type-Options nosniff
              X-Frame-Options SAMEORIGIN
              X-XSS-Protection "1; mode=block"
            }
          '';
        };
      };

      systemd.tmpfiles.rules = [
        "d ${cfg.dataDir} 0755 root root -"
        "d ${cfg.dataDir}/postgres17 0700 999 999 -"
      ]
      ++ lib.optional cfg.node.enable "d ${cfg.node.logDir} 0750 root root -";

      networking.firewall.allowedTCPPorts = lib.optional cfg.node.enable cfg.node.clientTcpPort;
      networking.firewall.allowedUDPPorts = lib.optional cfg.node.enable cfg.node.clientUdpPort;
      networking.firewall.extraCommands = lib.optionalString cfg.node.enable ''
        iptables -I nixos-fw -s 10.88.0.0/16 -p tcp --dport ${toString cfg.node.managementPort} -j nixos-fw-accept
      '';
      networking.firewall.extraStopCommands = lib.optionalString cfg.node.enable ''
        iptables -D nixos-fw -s 10.88.0.0/16 -p tcp --dport ${toString cfg.node.managementPort} -j nixos-fw-accept 2>/dev/null || true
      '';

      services.prometheus.scrapeConfigs = lib.mkIf config.cumserver.monitoring.enable [
        {
          job_name = "remnawave";
          metrics_path = "/metrics";
          basic_auth = {
            username = cfg.metricsUsername;
            password_file = cfg.metricsPasswordFile;
          };
          static_configs = [
            {
              targets = [ "127.0.0.1:${toString cfg.metricsPort}" ];
              labels = {
                node_type = "local";
              };
            }
          ];
          relabel_configs = [
            {
              target_label = "instance";
              replacement = config.cumserver.monitoring.localNodeName;
            }
          ];
        }
      ];
    })

    (lib.mkIf (cfg.enable && cfg.backup.enable) {
      services.restic.backups.remnawave = {
        user = "root";
        repository = "s3:https://b9b008414ac92325dff304821d2a0a2c.eu.r2.cloudflarestorage.com/bots-backups";
        passwordFile = config.age.secrets.resticBackupsPassword.path;
        environmentFile = config.age.secrets.resticS3Keys.path;
        initialize = true;
        paths = [ cfg.dataDir ];
        pruneOpts = [
          "--keep-daily 1"
          "--keep-weekly 5"
          "--keep-monthly 12"
        ];
        timerConfig = {
          OnCalendar = "04:35";
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
      };
    })

    (lib.mkIf (cfg.enable && cfg.node.enable) {
      systemd.services.remnawave-cert-sync = {
        description = "Refresh Remnawave Hysteria2 certificates";
        after = [
          "network-online.target"
          "remnawave.service"
        ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${remnawaveCertSync}/bin/remnawave-cert-sync";
          RuntimeDirectory = "remnawave-cert-sync";
          RuntimeDirectoryMode = "0700";
        };
      };

      systemd.timers.remnawave-cert-sync = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*-*-* 05,17:15:00";
          Persistent = true;
          RandomizedDelaySec = "15m";
          Unit = "remnawave-cert-sync.service";
        };
      };
    })
  ];
}
