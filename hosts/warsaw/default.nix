{
  config,
  pkgs,
  secrets,
  ...
}:

let
  domain = "waw.cum.army";
  tls = {
    enabled = true;
    certificate_path = "/var/lib/acme/${domain}/fullchain.pem";
    key_path = "/var/lib/acme/${domain}/key.pem";
  };
  tunnel = {
    log.level = "warn";
    inbounds = [
      {
        type = "vless";
        tag = "vless";
        listen = "0.0.0.0";
        listen_port = 2443;
        users = [ { uuid = "REPLACED_AT_RUNTIME"; } ];
        inherit tls;
        multiplex.enabled = true;
      }
    ];
    outbounds = [
      {
        type = "direct";
        tag = "xray";
      }
      {
        type = "block";
        tag = "block";
      }
    ];
    route = {
      rules = [
        {
          inbound = [ "vless" ];
          source_ip_cidr = [ "${secrets.ruRelayAddress}/32" ];
          network = "tcp";
          action = "route";
          outbound = "xray";
          override_address = "127.0.0.1";
          override_port = 2080;
        }
      ];
      final = "block";
    };
  };
  template = pkgs.writeText "warsaw-tunnel-template.json" (builtins.toJSON tunnel);
  render = pkgs.writeShellScript "render-warsaw-tunnel" ''
    set -eu
    ${pkgs.jq}/bin/jq --slurpfile auth "$CREDENTIALS_DIRECTORY/auth" \
      '.inbounds[0].users[0].uuid = $auth[0].vless' \
      ${template} > /run/warsaw-tunnels/config.json
  '';
in
{
  imports = [
    ../relay-common.nix
    ./disk-config.nix
  ];

  networking = {
    hostName = "warsaw";
    firewall = {
      allowedTCPPorts = [
        22
        80 # Standalone ACME HTTP-01 challenges
      ];
      extraInputRules = ''
        ip saddr ${secrets.cumserverAddress} tcp dport { 2080, 62052, 9100 } accept
        ip saddr ${secrets.ruRelayAddress} tcp dport { 2080, 2443 } accept
      '';
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "sleroq@cum.army";
    certs.${domain} = {
      listenHTTP = ":80";
      reloadServices = [ "warsaw-tunnels.service" ];
    };
  };

  age.secrets = {
    remnawaveNodeEnv.file = ./secrets/remnawaveNodeEnv.age;
    warsawTunnelAuth.file = ./secrets/warsawTunnelAuth.age;
  };

  virtualisation = {
    podman.enable = true;
    oci-containers.backend = "podman";
    oci-containers.containers.remnanode = {
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
  };
  systemd.tmpfiles.rules = [ "d /var/log/remnanode 0750 root root -" ];
  systemd.services = {
    podman-remnanode.restartTriggers = [ config.age.secrets.remnawaveNodeEnv.file ];
    warsaw-tunnels = {
      description = "RU-only multiplexed VLESS tunnel to local Remnawave node";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-online.target"
        "acme-${domain}.service"
      ];
      wants = [
        "network-online.target"
        "acme-${domain}.service"
      ];
      serviceConfig = {
        Type = "simple";
        DynamicUser = true;
        SupplementaryGroups = [ "acme" ];
        RuntimeDirectory = "warsaw-tunnels";
        RuntimeDirectoryMode = "0700";
        UMask = "0077";
        LoadCredential = "auth:${config.age.secrets.warsawTunnelAuth.path}";
        ExecStartPre = render;
        ExecStart = "${pkgs.sing-box}/bin/sing-box run -c /run/warsaw-tunnels/config.json";
        Restart = "on-failure";
        RestartSec = 5;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        CapabilityBoundingSet = [ ];
      };
    };
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDSh54pu9bAH8DFBKPtswFJzevCft+gHZStJQ0trYGoj sleroq@cum.army"
  ];
}
