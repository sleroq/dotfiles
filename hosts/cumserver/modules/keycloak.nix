{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cumserver.keycloak;
in
{
  options.cumserver.keycloak = {

    enable = lib.mkEnableOption "activate keycloak";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "auth.cum.army";
      description = ''
        keycloak domain
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 10480;
      description = ''
        Port being used for connections between NGINX & keycloak
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.keycloak = {
      enable = true;
      database.passwordFile = config.age.secrets.keycloak.path;

      settings = {
        hostname = "${cfg.domain}";
        http-port = cfg.port;
        http-host = "127.0.0.1";
        metrics-enabled = true;
        proxy-headers = "xforwarded";
        http-enabled = true;
      };

      initialAdminPassword = "changeme";

      themes.keywind = pkgs.stdenv.mkDerivation {
        name = "keywind";
        src = fetchGit {
          url = "https://github.com/lukin/keywind";
          rev = "bdf966fdae0071ccd46dab4efdc38458a643b409";
        };

        installPhase = ''
          mkdir -p $out
          cp -r $src/theme/keywind/* $out/
        '';
      };
    };

    services.caddy.virtualHosts = {
      ${cfg.domain} = {
        extraConfig = ''
          reverse_proxy 127.0.0.1:${toString cfg.port}
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
