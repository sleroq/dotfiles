{ config, ... }:
let
  domain = "turn-ru.cum.army";
  publicIPv4 = "185.147.26.212";
  acmeDir = "/var/lib/acme/${domain}";
  minPort = 49152;
  maxPort = 50100;
in
{
  age.secrets.coturnAuth = {
    file = ./secrets/coturnAuth.age;
    owner = "turnserver";
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "sleroq@cum.army";
    certs.${domain} = {
      webroot = "/var/lib/acme/acme-challenge";
      reloadServices = [ "coturn.service" ];
    };
  };

  services.caddy.virtualHosts."http://${domain}".extraConfig = ''
    bind 0.0.0.0

    handle /.well-known/acme-challenge/* {
      root * /var/lib/acme/acme-challenge
      file_server
    }

    respond 404
  '';

  services.coturn = {
    enable = true;
    realm = "cum.army";
    listening-ips = [ publicIPv4 ];
    relay-ips = [ publicIPv4 ];
    min-port = minPort;
    max-port = maxPort;
    use-auth-secret = true;
    static-auth-secret-file = config.age.secrets.coturnAuth.path;
    cert = "${acmeDir}/fullchain.pem";
    pkey = "${acmeDir}/key.pem";
    no-tcp-relay = true;
    no-cli = true;
    extraConfig = ''
      relay-threads=2
    '';
  };

  systemd.services.caddy.serviceConfig.SupplementaryGroups = [ "acme" ];

  systemd.services.coturn = {
    requires = [ "acme-${domain}.service" ];
    after = [ "acme-${domain}.service" ];
    serviceConfig.SupplementaryGroups = [ "acme" ];
  };

  networking.firewall = {
    allowedTCPPorts = [
      3478
      5349
    ];
    allowedUDPPorts = [
      3478
      5349
    ];
    allowedUDPPortRanges = [
      {
        from = minPort;
        to = maxPort;
      }
    ];
  };
}
