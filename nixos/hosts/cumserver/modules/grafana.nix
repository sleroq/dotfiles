{ config, pkgs, lib, ... }:
let
  cfg = config.cumserver.grafana;
in
{
  options.cumserver.grafana.enable = lib.mkEnableOption "Grafana";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.caddy.enable;
        message = "Caddy has to be enabled for Grafana to work";
      }
    ];

    age.secrets.grafanaPassword = {
        owner = "grafana";
        group = "grafana";
        file = ../secrets/grafanaPassword;
    };

    services.grafana = {
        enable = true;
        settings = {
            server = {
                http_addr = "127.0.0.1";
                http_port = 3200;
                root_url = "https://cum.army/grafana/";
            };
            security = {
                admin_user = "sleroq";
                admin_password = "$__file{${config.age.secrets.grafanaPassword.path}}";
            };
        };
    };

    services.prometheus = {
        enable = true;
        scrapeConfigs = [
            {
                job_name = "prometheus";
                static_configs = [{ targets = [ "127.0.0.1:9090" ]; }];
            }
            {
                job_name = "node";
                static_configs = [{ targets = [ "127.0.0.1:9100" ]; }];
            }
        ];
        exporters = {
            node = {
                enable = true;
                enabledCollectors = [ "systemd" "processes" ];
            };
        };
    };

    services.caddy = {
      virtualHosts = {
        "cum.army" = {
          extraConfig = ''
            handle_path /grafana/* {
                reverse_proxy 127.0.0.1:3200
            }
          '';
        };
      };
    };
  };
}
