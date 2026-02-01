{ config, lib, secrets, ... }:
let
  cfg = config.cumserver.frp;
in
{
  options.cumserver.frp = {
    enable = lib.mkEnableOption "frp";
  };

  config = lib.mkIf cfg.enable {
    services.frp = {
      instances.frps = {
        enable = true;
        role = "server";
        settings = {
          bindPort = 7000;

          auth = {
            method = "token";
            token = secrets.frpToken;
          };

          webServer = {
            addr = "127.0.0.1";
            port = 7500;
          };
          enablePrometheus = true;
        };
      };
    };

    networking.firewall.allowedTCPPorts = [ 7000 27015 ];
    networking.firewall.allowedUDPPorts = [ 27015 ];
  };
}
