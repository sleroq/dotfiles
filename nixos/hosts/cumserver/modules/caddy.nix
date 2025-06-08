{ inputs, pkgs, config, lib, ... }:
let
  cfg = config.cumserver.caddy;
in
{
  options.cumserver.caddy.enable = lib.mkEnableOption "Caddy";

  config = lib.mkIf cfg.enable {
    age.secrets.cf-fullchain = {
      owner = "caddy";
      group = "caddy";
      file = ../secrets/cf-fullchain.pem;
    };
    age.secrets.cf-privkey = {
      owner = "caddy";
      group = "caddy";
      file = ../secrets/cf-privkey.pem;
    };

    services.caddy = {
      enable = true;
      email = "admin@sleroq.link";

      virtualHosts = {
        "sleroq.link" = {
          serverAliases = [ "www.sleroq.link" ];
          extraConfig = ''
            tls ${config.age.secrets.cf-fullchain.path} ${config.age.secrets.cf-privkey.path}

            root * ${inputs.sleroq-link.packages."${pkgs.system}".default}
            file_server
            encode zstd gzip

            handle_path /.well-known/matrix/server {
                header Access-Control-Allow-Origin *
                respond `{"m.server": "m.sleroq.link:443"}` 200
            }

            handle_path /.well-known/matrix/client {
                header Access-Control-Allow-Origin *
                respond `{"m.homeserver": {"base_url": "https://m.sleroq.link"}}` 200
            }
          '';
        };

        "cum.army" = {
          serverAliases = [ "www.cum.army" ];
          extraConfig = ''
            root * ${inputs.cum-army.packages."${pkgs.system}".default}
            file_server
            encode zstd gzip
          '';
        };

        # Bore tunnel subdomains will be added dynamically by the bore module

        # "m.sleroq.link" = {
        #   extraConfig = ''
        #     reverse_proxy localhost:8008
        #   '';
        # };
      };
    };

    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}
