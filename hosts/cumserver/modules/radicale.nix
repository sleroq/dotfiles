{ config, lib, ... }:

let
  cfg = config.cumserver.radicale;
in
{
  options.cumserver.radicale = {
    enable = lib.mkEnableOption "Radicale";
    backup.enable = lib.mkEnableOption "backups" // { default = true; };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
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
    })

    (lib.mkIf (cfg.enable && cfg.backup.enable) {
      age.secrets.resticMailPassword = {
        owner = "root";
        group = "restic-mail-backups";
        mode = "0440";
        file = ../secrets/resticMailPassword;
      };

      users.groups.restic-mail-backups.members = [ "radicale" ];
      users.groups.restic-s3-backups.members = [ "virtualMail" ];

      services.restic.backups.radicale = {
        user = "radicale";
        repository = "s3:https://b9b008414ac92325dff304821d2a0a2c.eu.r2.cloudflarestorage.com/backups";
        passwordFile = config.age.secrets.resticMailPassword.path;
        environmentFile = config.age.secrets.resticS3Keys.path;
        initialize = true;
        paths = [ "/var/lib/radicale/" ];
        exclude = [
          "**/.Radicale.cache/*"
        ];
        pruneOpts = [
          "--keep-daily 7"
          "--keep-weekly 5"
          "--keep-monthly 12"
        ];
        timerConfig = {
          OnCalendar = "02:35";
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
      };
    })
  ];
}
