{ config, lib, ... }:

let
  cfg = config.cumserver.attic;
in
{
  options.cumserver.attic = {
    enable = lib.mkEnableOption "Attic binary cache";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "cache.cum.army";
      description = "Public domain for the Attic binary cache";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8084;
      description = "Attic loopback port";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.caddy.enable;
        message = "Attic requires Caddy for its public HTTPS endpoint";
      }
    ];

    age.secrets.atticServerToken = {
      file = ../secrets/atticServerToken;
    };

    services.atticd = {
      enable = true;
      environmentFile = config.age.secrets.atticServerToken.path;
      settings = {
        listen = "127.0.0.1:${toString cfg.port}";
        api-endpoint = "https://${cfg.domain}/";
        allowed-hosts = [ cfg.domain ];

        garbage-collection = {
          interval = "12 hours";
          default-retention-period = "30 days";
        };
      };
    };

    services.caddy.virtualHosts.${cfg.domain}.extraConfig = ''
      reverse_proxy 127.0.0.1:${toString cfg.port}
    '';

    nix.settings = {
      extra-substituters = [ "https://${cfg.domain}/reactor" ];
      extra-trusted-public-keys = [ "reactor:6zTPyqXJya+MKMFxKL/KvobYqjD2Bh/tvPS9FM+pNlo=" ];
    };
  };
}
