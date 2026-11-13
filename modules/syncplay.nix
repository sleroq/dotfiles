{
  config,
  lib,
  ...
}:
let
  cfg = config.cumserver.syncplay;
in
{
  options.cumserver.syncplay = {
    enable = lib.mkEnableOption "Syncplay";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "watch.cum.army";
      description = "Domain name for Syncplay";
    };

    port = lib.mkOption {
      type = lib.types.int;
      default = 8999;
      description = "Port for Syncplay to be exposed on all interfaces";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.caddy.enable;
        message = "Caddy has to be enabled to complete the Syncplay ACME challenge";
      }
    ];

    security.acme = {
      acceptTerms = true;
      defaults.email = config.services.caddy.email;
      certs.${cfg.domain} = {
        webroot = "/var/lib/acme/acme-challenge";
      };
    };

    users.users.caddy.extraGroups = [ "acme" ];

    services.caddy.virtualHosts."http://${cfg.domain}".extraConfig = ''
      handle /.well-known/acme-challenge/* {
        root * /var/lib/acme/acme-challenge
        file_server
      }

      respond ""
    '';

    services.syncplay = {
      enable = true;
      port = cfg.port;
      # NixOS presents the renewed ACME certificate to Syncplay as
      # cert.pem, privkey.pem, and chain.pem in its credential directory.
      useACMEHost = cfg.domain;
    };
  };
}
