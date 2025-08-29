{ inputs', config, lib, ... }:
let
  cfg = config.cumserver.caddy;
in
{
  options.cumserver.caddy.enable = lib.mkEnableOption "Caddy";

  # TODO: Solve {"level":"warn","ts":1756318480.6253746,"logger":"caddyfile","msg":"Unnecessary header_up X-Forwarded-For: the reverse proxy's default behavior is to pass headers to the upstream"}

  config = lib.mkIf cfg.enable {
    services.caddy = {
      enable = true;
      email = "admin@sleroq.link";
      virtualHosts = {
        "cum.army" = {
          serverAliases = [ "www.cum.army" ];
          extraConfig = ''
            root * ${inputs'.cum-army.packages.default}
            encode zstd gzip

            # Shortcut for fauna pic to avoid /u/
            redir /fauna /u/fauna.png 308
            file_server

            ${lib.optionalString config.cumserver.zipline.enable ''
            handle_errors {
              @notfound expression {http.error.status_code} == 404
              handle @notfound {
                reverse_proxy localhost:${toString config.cumserver.zipline.port}
              }
            }''}
          ''; # TODO: This can probably be moved to zipline server and simplified
        };
      };
    };

    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}
