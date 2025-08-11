{ config, lib, ... }:

let
  cfg = config.cumserver.radicale;
in
{
  options.cumserver.radicale.enable = lib.mkEnableOption "Radicale";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.caddy.enable;
        message = "Caddy has to be enabled for radicale to work";
      }
      {
        assertion = config.cumserver.mailserver.enable;
        message = "Mail server has to be enabled for radicale auth to work";
      }
    ];

    services.radicale = {
      enable = true;
      settings = {
        server = {
          max_connections = 20;
          max_content_length = 100000000; # 100 megabyte
          timeout = 30;
          hosts = [ "127.0.0.1:5232" ];
        };

        auth = {
          type = "imap";
          imap_host = config.mailserver.fqdn;
        };
      };
    };

    services.caddy = {
      virtualHosts = {
        "cum.army" = {
          extraConfig = ''
            handle_path /radicale/* {
                uri strip_prefix /radicale
                reverse_proxy localhost:5232 {
                    header_up X-Script-Name /radicale
                }
            }
          '';
        };
      };
    };
  };
}
