{ config, lib, ... }:

let
  cfg = config.sleroq.sftpgo;
in
{
  options.sleroq.sftpgo = {
    enable = lib.mkEnableOption "SFTPGo for the Navidrome music library with a Cloudflare Tunnel route";

    musicFolder = lib.mkOption {
      type = lib.types.path;
      description = "Navidrome music directory to expose through SFTPGo.";
    };

    adminEnvironmentFile = lib.mkOption {
      type = lib.types.path;
      description = "Environment file defining the initial SFTPGo administrator credentials.";
    };

    usersFile = lib.mkOption {
      type = lib.types.path;
      description = "SFTPGo data file defining the music-library users and their permissions.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8099;
      description = "Local port on which SFTPGo's web client and API listen.";
    };

    cloudflared = {
      tunnel = lib.mkOption {
        type = lib.types.str;
        description = "Name of the locally managed Cloudflare Tunnel that routes to SFTPGo.";
      };

      hostname = lib.mkOption {
        type = lib.types.str;
        description = "Public hostname for SFTPGo.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.navidrome.enable;
        message = "Navidrome must be enabled for SFTPGo to use the navidrome user and music directory";
      }
    ];

    services.sftpgo = {
      enable = true;
      user = "navidrome";
      group = "navidrome";
      extraReadWriteDirs = [ cfg.musicFolder ];
      loadDataFile = cfg.usersFile;
      settings.httpd.bindings = [
        {
          address = "127.0.0.1";
          port = cfg.port;
          enable_web_admin = true;
          enable_web_client = true;
        }
      ];
    };

    systemd.services.sftpgo.serviceConfig.EnvironmentFile = cfg.adminEnvironmentFile;
    systemd.services.sftpgo.environment.SFTPGO_LOADDATA_MODE = "0";

    sleroq.cloudflared.tunnels.${cfg.cloudflared.tunnel}.routes.${cfg.cloudflared.hostname} =
      "http://127.0.0.1:${toString cfg.port}";
  };
}
