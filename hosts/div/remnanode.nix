{ config, pkgs, ... }:

let
  managementPort = 62053;
  vlessPort = 2080;
  hysteriaPort = 8443;
in
{
  age.secrets.remnawaveNodeEnv.file = ./secrets/remnawaveNodeEnv;

  virtualisation.oci-containers.containers.remnanode = {
    autoStart = true;
    image = "docker.io/remnawave/node:2.8.0";
    environmentFiles = [ config.age.secrets.remnawaveNodeEnv.path ];
    extraOptions = [
      "--network=host"
      "--cap-add=NET_ADMIN"
      "--ulimit=nofile=1048576:1048576"
    ];
    volumes = [ "/var/log/remnanode:/var/log/remnanode" ];
  };

  systemd.tmpfiles.rules = [
    "d /var/log/remnanode 0750 root root -"
  ];

  # Hysteria2 sends 1280-byte QUIC datagrams. Tailscale's default 1280-byte
  # interface MTU cannot carry those datagrams plus their IP/UDP headers.
  systemd.services.remnawave-tailscale-mtu = {
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

  # The panel and public relay both reach div privately. No Remnawave port is
  # exposed on div's public interface.
  networking.firewall.interfaces.tailscale0 = {
    allowedTCPPorts = [
      managementPort
      vlessPort
    ];
    allowedUDPPorts = [ hysteriaPort ];
  };
}
