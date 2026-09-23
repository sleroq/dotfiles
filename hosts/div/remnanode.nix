{ config, ... }:

let
  managementPort = 62053;
  vlessPort = 2080;
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

  # The panel and public relay both reach div privately. No Remnawave port is
  # exposed on div's public interface.
  networking.firewall.interfaces.tailscale0 = {
    allowedTCPPorts = [
      managementPort
      vlessPort
    ];
  };
}
