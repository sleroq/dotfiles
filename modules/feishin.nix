{ config, lib, ... }:

let
  cfg = config.sleroq.feishin;
in
{
  options.sleroq.feishin = {
    enable = lib.mkEnableOption "Feishin music client with a Cloudflare Tunnel route";

    port = lib.mkOption {
      type = lib.types.port;
      default = 9180;
      description = "Local port on which Feishin listens.";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/jeffvli/feishin:latest";
      description = "OCI image to use for Feishin.";
    };

    serverName = lib.mkOption {
      type = lib.types.str;
      default = "sleroq";
      description = "Name displayed for the configured music server.";
    };

    serverUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://music.cum.army";
      description = "Public Navidrome URL used by Feishin.";
    };

    timeZone = lib.mkOption {
      type = lib.types.str;
      default = "Europe/Istanbul";
      description = "Time zone used by the Feishin container.";
    };

    webAudio = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether new Feishin web clients use the Web Audio playback path.";
    };

    cloudflared = {
      tunnel = lib.mkOption {
        type = lib.types.str;
        description = "Name of the locally managed Cloudflare Tunnel that routes to Feishin.";
      };

      hostname = lib.mkOption {
        type = lib.types.str;
        description = "Public hostname for Feishin.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.virtualisation.oci-containers.backend != null;
        message = "OCI containers backend must be configured for Feishin to work";
      }
    ];

    virtualisation.oci-containers.containers.feishin = {
      inherit (cfg) image;
      autoStart = true;
      pull = "newer";
      ports = [ "127.0.0.1:${toString cfg.port}:9180" ];
      environment = {
        SERVER_NAME = cfg.serverName;
        SERVER_LOCK = "true";
        SERVER_TYPE = "navidrome";
        SERVER_URL = cfg.serverUrl;
        TZ = cfg.timeZone;
        FS_PLAYBACK_WEB_AUDIO = lib.boolToString cfg.webAudio;
      };
      extraOptions = [ "--hostname=feishin" ];
    };

    sleroq.cloudflared.tunnels.${cfg.cloudflared.tunnel}.routes.${cfg.cloudflared.hostname} =
      "http://127.0.0.1:${toString cfg.port}";
  };
}
