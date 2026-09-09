{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cumserver.remnawaveDivRelay;
in
{
  options.cumserver.remnawaveDivRelay = {
    enable = lib.mkEnableOption "public Remnawave relay to div";

    targetAddress = lib.mkOption {
      type = lib.types.str;
      default = "100.110.59.70";
      description = "div's stable Tailscale IPv4 address";
    };

    publicTcpPort = lib.mkOption {
      type = lib.types.port;
      default = 2081;
      description = "Public VLESS port on cumserver";
    };

    targetTcpPort = lib.mkOption {
      type = lib.types.port;
      default = 2080;
      description = "VLESS port on div";
    };

    publicUdpPort = lib.mkOption {
      type = lib.types.port;
      default = 8444;
      description = "Public Hysteria2 port on cumserver";
    };

    targetUdpPort = lib.mkOption {
      type = lib.types.port;
      default = 8443;
      description = "Hysteria2 port on div";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.tailscale.enable;
        message = "Tailscale must be enabled for the div Remnawave relay";
      }
    ];

    services.nginx = {
      enable = true;
      streamConfig = ''
        server {
          listen ${toString cfg.publicUdpPort} udp reuseport;
          proxy_pass ${cfg.targetAddress}:${toString cfg.targetUdpPort};
          proxy_timeout 1m;
        }
      '';
    };

    systemd.services = {
      remnawave-div-tcp-relay = {
        description = "TCP relay for the div Remnawave node";
        wantedBy = [ "multi-user.target" ];
        after = [ "tailscaled.service" ];
        requires = [ "tailscaled.service" ];
        serviceConfig = {
          ExecStart = "${pkgs.socat}/bin/socat TCP-LISTEN:${toString cfg.publicTcpPort},reuseaddr,fork TCP:${cfg.targetAddress}:${toString cfg.targetTcpPort}";
          Restart = "always";
          RestartSec = 2;
        };
      };

      remnawave-tailscale-mtu = {
        description = "Raise the Tailscale MTU for Remnawave Hysteria2";
        wantedBy = [ "multi-user.target" ];
        after = [ "tailscaled.service" ];
        requires = [ "tailscaled.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.iproute2}/bin/ip link set dev tailscale0 mtu 1360";
        };
      };
    };

    networking.firewall = {
      allowedTCPPorts = [ cfg.publicTcpPort ];
      allowedUDPPorts = [ cfg.publicUdpPort ];
    };
  };
}
