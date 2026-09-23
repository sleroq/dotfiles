{
  secrets,
  ...
}:

let
  mainRelayPort = 443;
  divRelayPort = 2081;
  directWarsawPort = 2082;
  backendAddress = secrets.cumserverAddress;
  warsawAddress = secrets.warsawAddress;
  divBackendPort = 2081;
in
{
  imports = [
    ../relay-common.nix
    ./disk-config.nix
    ./warsaw-tunnels.nix
  ];

  networking = {
    hostName = "ru-relay";
    firewall = {
      allowedTCPPorts = [
        22
        mainRelayPort
        divRelayPort
        directWarsawPort
      ];
      # Metrics are scraped only by cumserver, never exposed to clients.
      extraInputRules = ''
        ip saddr ${backendAddress} tcp dport 9100 accept
      '';
    };
  };

  services = {
    haproxy = {
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

        frontend warsaw_ingress
          bind 0.0.0.0:${toString mainRelayPort}
          no log
          default_backend warsaw_beats_tunnel

        backend warsaw_beats_tunnel
          server local_tunnel 127.0.0.1:12084 check

        frontend warsaw_direct_ingress
          bind 0.0.0.0:${toString directWarsawPort}
          no log
          default_backend warsaw_direct

        backend warsaw_direct
          option tcp-check
          default-server inter 5s fastinter 1s downinter 1s rise 2 fall 3
          server warsaw ${warsawAddress}:2084 check

        frontend div_ingress
          bind 0.0.0.0:${toString divRelayPort}
          no log
          default_backend cumserver_div

        backend cumserver_div
          option tcp-check
          default-server inter 5s fastinter 1s downinter 1s rise 2 fall 3
          server cumserver ${backendAddress}:${toString divBackendPort} check
      '';
    };

  };

  systemd.services.haproxy.serviceConfig = {
    LimitNOFILE = 65536;
    OOMScoreAdjust = -500;
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIC6y8gKcayme82pVdIJnui/ZSeSnI7t8Fl+WZFPDO9i cantundo@pm.me warsaw"
  ];
}
