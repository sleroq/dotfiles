{ config, lib, ... }:
let
  cfg = config.cumserver.frp;
in
{
  options.cumserver.frp = {
    enable = lib.mkEnableOption "frp";
  };

  config = lib.mkIf cfg.enable {
    age.secrets.frpToken.file = ../secrets/frpToken;
    systemd.services.frp-frps.serviceConfig.LoadCredential =
      "frp-token:${config.age.secrets.frpToken.path}";

    services.frp = {
      instances.frps = {
        enable = true;
        role = "server";
        settings = {
          bindPort = 7000;

          auth = {
            method = "token";
            tokenSource = {
              type = "file";
              file.path = "/run/credentials/frp-frps.service/frp-token";
            };
          };

          webServer = {
            addr = "127.0.0.1";
            port = 7500;
          };
          enablePrometheus = true;
        };
      };
    };

    networking.firewall.allowedTCPPorts = [
      7000
      27015
      28801
    ];
    networking.firewall.allowedUDPPorts = [
      27015
      28802
    ];
  };
}
