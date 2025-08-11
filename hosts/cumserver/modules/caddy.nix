{ inputs', config, lib, ... }:
let
  cfg = config.cumserver.caddy;
in
{
  options.cumserver.caddy.enable = lib.mkEnableOption "Caddy";

  config = lib.mkIf cfg.enable {
    services.caddy = {
      enable = true;
      email = "admin@sleroq.link";
      virtualHosts = {
        "cum.army" = {
          serverAliases = [ "www.cum.army" ];
          extraConfig = ''
            root * ${inputs'.cum-army.packages.default}
            file_server
            encode zstd gzip
          '';
        };
      };
    };

    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}
