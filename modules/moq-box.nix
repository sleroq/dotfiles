{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.moq-box;
  packages = pkgs.callPackage ../packages/moq-box.nix { };
  cli = "${packages.moq}/bin/moq";
  stateDir = "/var/lib/moq-box";
  acmeDir = "/var/lib/acme/${cfg.relayDomain}";
  relayConfig = (pkgs.formats.toml { }).generate "moq-relay.toml" {
    listen = {
      bind = "0.0.0.0:${toString cfg.port}";
      tls = {
        cert = "${acmeDir}/fullchain.pem";
        key = "${acmeDir}/key.pem";
      };
    };
    web.https = {
      listen = "127.0.0.1:${toString cfg.httpsPort}";
      cert = "${acmeDir}/fullchain.pem";
      key = "${acmeDir}/key.pem";
    };
    auth.url = "http://127.0.0.1:${toString cfg.authPort}/";
    internal.listen = "127.0.0.1:${toString cfg.metricsPort}";
    cache = {
      capacity = "64MiB";
      duration = "10s";
    };
    log.level = "info";
  };
  hardening = {
    User = "moq-box";
    Group = "moq-box";
    NoNewPrivileges = true;
    PrivateTmp = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    Restart = "on-failure";
    RestartSec = "5s";
    UMask = "0077";
  };
in
{
  options.services.moq-box = {
    enable = lib.mkEnableOption "MoQ relay and authentication";
    relayDomain = lib.mkOption {
      type = lib.types.str;
      description = "Direct DNS-only relay hostname";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 443;
      description = "Public QUIC UDP port";
    };
    httpsPort = lib.mkOption {
      type = lib.types.port;
      default = 9443;
      description = "Local HTTPS/WebSocket listener, reached by TLS passthrough";
    };
    authPort = lib.mkOption {
      type = lib.types.port;
      default = 4440;
      description = "Loopback auth service port";
    };
    metricsPort = lib.mkOption {
      type = lib.types.port;
      default = 9101;
      description = "Loopback operational listener port";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.caddy.enable;
        message = "moq-box requires Caddy for the HTTP ACME challenge";
      }
    ];

    users.users.moq-box = {
      isSystemUser = true;
      group = "moq-box";
    };
    users.groups.moq-box = { };

    security.acme = {
      acceptTerms = true;
      defaults.email = "sleroq@cum.army";
      certs.${cfg.relayDomain} = {
        webroot = "/var/lib/acme/acme-challenge";
      };
    };

    services.caddy.virtualHosts = {
      "http://${cfg.relayDomain}".extraConfig = ''
        bind 0.0.0.0
        handle /.well-known/acme-challenge/* {
          root * /var/lib/acme/acme-challenge
          file_server
        }
        respond 404
      '';

    };

    systemd.services.moq-auth = {
      description = "MoQ JWT verification and public read-only live streams";
      wantedBy = [ "multi-user.target" ];
      before = [ "moq-relay.service" ];
      preStart = ''
        if [ ! -f ${stateDir}/root.jwk ]; then
          ${cli} auth generate --algorithm ES256 --out ${stateDir}/root.jwk
        fi
      '';
      serviceConfig = hardening // {
        StateDirectory = "moq-box";
        StateDirectoryMode = "0700";
        ExecStart = "${cli} auth serve --listen 127.0.0.1:${toString cfg.authPort} --key ${stateDir}/root.jwk --public-subscribe '**'";
      };
    };

    systemd.services.moq-relay = {
      description = "Media over QUIC relay";
      wantedBy = [ "multi-user.target" ];
      requires = [
        "moq-auth.service"
        "acme-${cfg.relayDomain}.service"
      ];
      after = [
        "network-online.target"
        "moq-auth.service"
        "acme-${cfg.relayDomain}.service"
      ];
      wants = [ "network-online.target" ];
      serviceConfig = hardening // {
        ExecStart = "${packages.moq-relay}/bin/moq-relay ${relayConfig}";
        SupplementaryGroups = [ "acme" ];
        AmbientCapabilities = lib.optional (cfg.port < 1024) "CAP_NET_BIND_SERVICE";
        CapabilityBoundingSet = lib.optional (cfg.port < 1024) "CAP_NET_BIND_SERVICE";
        MemoryHigh = "192M";
        MemoryMax = "256M";
      };
    };

    environment.systemPackages = [ packages.moq ];
    networking.firewall.allowedUDPPorts = [ cfg.port ];
    boot.kernel.sysctl = {
      "net.core.rmem_max" = 8388608;
      "net.core.wmem_max" = 8388608;
    };
  };
}
