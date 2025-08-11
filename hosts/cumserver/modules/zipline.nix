{ config, lib, ... }:

let
  cfg = config.cumserver.zipline;
in
{
  options.cumserver.zipline = {
    enable = lib.mkEnableOption "Zipline file sharing server";
    
    domain = lib.mkOption {
      type = lib.types.str;
      default = "share.cum.army";
      description = "Domain name for Zipline";
    };
    
    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Internal port for Zipline";
    };

    environmentFile = lib.mkOption {
      type = lib.types.path;
      description = "Environment file for Zipline";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.caddy.enable;
        message = "Caddy has to be enabled for Zipline to work";
      }
    ];

    services.zipline = {
      enable = true;
      
      environmentFiles = [ cfg.environmentFile ];
      
      settings = {
        CORE_PORT = cfg.port;
      };
      
      database.createLocally = true;
    };

    services.caddy.virtualHosts = {
      ${cfg.domain} = {
        extraConfig = ''
          reverse_proxy localhost:${toString cfg.port}
          encode zstd gzip
          
          header {
            X-Content-Type-Options nosniff
            X-Frame-Options SAMEORIGIN
            X-XSS-Protection "1; mode=block"
          }
        '';
      };
    };
  };
} 
