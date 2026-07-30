{ config, lib, ... }:
let
  cfg = config.sleroq.slusha;
in
{
  options.sleroq.slusha = {
    enable = lib.mkEnableOption "Slusha Telegram bot";
    image = lib.mkOption {
      type = lib.types.str;
      description = "OCI image to run";
    };
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/slusha";
      description = "Directory containing Slusha's persistent data";
    };
    environmentFile = lib.mkOption {
      type = lib.types.path;
      description = "Environment file containing Slusha secrets";
    };
    cloudflared = {
      tunnel = lib.mkOption {
        type = lib.types.str;
        description = "Locally managed Cloudflare Tunnel that serves Slusha";
      };
      hostname = lib.mkOption {
        type = lib.types.str;
        default = "slusha.cum.army";
        description = "Public hostname for Slusha";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.virtualisation.oci-containers.backend != null;
        message = "OCI containers backend must be configured for Slusha to work";
      }
    ];
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 65532 65532 -"
      "d ${cfg.dataDir}/tmp 0750 65532 65532 -"
      "d ${cfg.dataDir}/log 0750 65532 65532 -"
      "d ${cfg.dataDir}/data 0750 65532 65532 -"
    ];
    virtualisation.oci-containers.containers.slusha = {
      inherit (cfg) image;
      autoStart = true;
      pull = "newer";
      ports = [ "127.0.0.1:18080:8080" ];
      environmentFiles = [ cfg.environmentFile ];
      user = "65532:65532";
      environment.DENO_DIR = "/app/tmp/deno";
      volumes = [
        "${cfg.dataDir}/data:/app/data"
        "${cfg.dataDir}/tmp:/app/tmp"
        "${cfg.dataDir}/log:/app/log"
      ];
    };
    sleroq.cloudflared.tunnels.${cfg.cloudflared.tunnel}.routes.${cfg.cloudflared.hostname} =
      "http://127.0.0.1:18080";
  };
}
