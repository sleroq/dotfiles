{
  config,
  lib,
  secrets,
  ...
}:

let
  cfg = config.cumserver.remnawaveRelays;
in
{
  options.cumserver.remnawaveRelays = {
    enable = lib.mkEnableOption "private Remnawave relays for the RU ingress";

    allowedSource = lib.mkOption {
      type = lib.types.str;
      default = secrets.ruRelayIP;
      description = "Public IPv4 address allowed to use the relay listeners";
    };

    div = {
      listenPort = lib.mkOption {
        type = lib.types.port;
        default = 2081;
        description = "TCP port receiving div traffic from the RU relay";
      };

      targetAddress = lib.mkOption {
        type = lib.types.str;
        default = secrets.divTailscaleIP;
        description = "div's stable Tailscale IPv4 address";
      };

      targetPort = lib.mkOption {
        type = lib.types.port;
        default = 2080;
        description = "VLESS port on div";
      };
    };

    warsaw = {
      listenPort = lib.mkOption {
        type = lib.types.port;
        default = 2082;
        description = "TCP port receiving Warsaw traffic from the RU relay";
      };

      targetAddress = lib.mkOption {
        type = lib.types.str;
        default = secrets.polandNodeIP;
        description = "Warsaw Remnawave node address";
      };

      targetPort = lib.mkOption {
        type = lib.types.port;
        default = 2080;
        description = "VLESS port on the Warsaw node";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.tailscale.enable;
        message = "Tailscale must be enabled for the div Remnawave relay";
      }
    ];

    services.haproxy = {
      enable = true;
      config = ''
        log stdout format raw local0 info
        maxconn 8192

        defaults
          log global
          mode tcp
          option clitcpka
          option srvtcpka
          option dontlognull
          retries 2
          timeout connect 5s
          timeout client 24h
          timeout server 24h
          timeout client-fin 30s
          timeout server-fin 30s

        frontend div_ingress
          bind 0.0.0.0:${toString cfg.div.listenPort}
          no log
          default_backend div_xray

        backend div_xray
          option tcp-check
          default-server inter 5s fastinter 1s downinter 1s rise 2 fall 3
          server div ${cfg.div.targetAddress}:${toString cfg.div.targetPort} check

        frontend warsaw_ingress
          bind 0.0.0.0:${toString cfg.warsaw.listenPort}
          no log
          default_backend warsaw_xray

        backend warsaw_xray
          option tcp-check
          default-server inter 5s fastinter 1s downinter 1s rise 2 fall 3
          server warsaw ${cfg.warsaw.targetAddress}:${toString cfg.warsaw.targetPort} check
      '';
    };

    systemd.services.haproxy = {
      after = [ "tailscaled.service" ];
      wants = [ "tailscaled.service" ];
      serviceConfig = {
        LimitNOFILE = 65536;
        OOMScoreAdjust = -500;
        CapabilityBoundingSet = [ ];
        LockPersonality = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_UNIX"
        ];
        RestrictRealtime = true;
        SystemCallArchitectures = "native";
      };
    };

    # These listeners are transit-only and must not be reachable from arbitrary
    # Internet clients. Clients connect to the replaceable RU relay instead.
    networking.firewall.extraCommands = ''
      iptables -I nixos-fw -s ${cfg.allowedSource} -p tcp -m multiport --dports ${toString cfg.div.listenPort},${toString cfg.warsaw.listenPort} -j nixos-fw-accept
    '';
    networking.firewall.extraStopCommands = ''
      iptables -D nixos-fw -s ${cfg.allowedSource} -p tcp -m multiport --dports ${toString cfg.div.listenPort},${toString cfg.warsaw.listenPort} -j nixos-fw-accept 2>/dev/null || true
    '';
  };
}
