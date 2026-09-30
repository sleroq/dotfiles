{
  pkgs,
  secrets,
  ...
}:

let
  mainRelayPort = 443;
  divRelayPort = 2081;
  directWarsawPort = 2082;
  backendAddress = secrets.cumserverAddress;
  warsawAddress = secrets.warsawAddress;
  warsawBackendPort = 2082;
  divBackendPort = 2081;
in
{
  imports = [
    ../relay-common.nix
    ./disk-config.nix
    ./coturn.nix
    ./warsaw-tunnels.nix
    ../../modules/broadcast-box.nix
  ];

  networking = {
    hostName = "ru-relay";
    firewall = {
      allowedTCPPorts = [
        22
        80
        mainRelayPort
        divRelayPort
        directWarsawPort
        2080 # Legacy Warsaw host via Germany's Remnawave relay
      ];
      # Metrics are scraped only by cumserver, never exposed to clients.
      extraInputRules = ''
        ip saddr ${backendAddress} tcp dport 9100 accept
      '';
    };
  };

  cumserver.broadcast-box = {
    enable = true;
    publicIPv4 = "185.147.26.212";
    instances.production = {
      domain = "alt-web.cum.army";
      port = 8080;
      udpPort = 8080;
      redisPort = 6379;
      redisDb = 0;
      stateDirectory = "broadcast-box";
      package = pkgs.broadcast-box.override {
        version = "unstable-2026-09-28";
        rev = "f4b084b86b5397dfcd41641aec0f3bf953acac31";
        hash = "sha256-3uabwwnLs2hCfKk7cUw5ZCN9Ig39lU0pl28NYOlSYqU=";
      };
      backup.enable = false;
    };
  };

  services = {
    caddy = {
      enable = true;
      email = "sleroq@cum.army";
      globalConfig = ''
        https_port 8443
        default_bind 127.0.0.1
        servers {
          protocols h1 h2
        }
      '';
      virtualHosts."http://alt-web.cum.army".extraConfig = ''
        bind 0.0.0.0
        redir https://alt-web.cum.army{uri} permanent
      '';
    };

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
          tcp-request inspect-delay 5s
          tcp-request content accept if { req.ssl_hello_type 1 }
          use_backend broadcast_box_https if { req.ssl_sni -i alt-web.cum.army }
          default_backend warsaw_beats_tunnel

        backend broadcast_box_https
          server caddy 127.0.0.1:8443 check

        backend warsaw_beats_tunnel
          server local_tunnel 127.0.0.1:12084 check

        frontend warsaw_germany_ingress
          bind 0.0.0.0:2080
          no log
          default_backend cumserver_warsaw

        backend cumserver_warsaw
          option tcp-check
          default-server inter 5s fastinter 1s downinter 1s rise 2 fall 3
          server cumserver ${backendAddress}:${toString warsawBackendPort} check

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

  # Apply routing changes with HAProxy's graceful reload, preserving proxy connections.
  systemd.services.haproxy.reloadIfChanged = true;
  systemd.services.haproxy.serviceConfig = {
    LimitNOFILE = 65536;
    OOMScoreAdjust = -500;
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIC6y8gKcayme82pVdIJnui/ZSeSnI7t8Fl+WZFPDO9i cantundo@pm.me warsaw"
  ];
}
