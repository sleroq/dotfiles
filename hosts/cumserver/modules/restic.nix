{ config, lib, ... }:
let
  cfg = config.cumserver.restic;
  port = 8040;
in
{
  options.cumserver.restic = {
    enable = lib.mkEnableOption "restic REST server";
    port = lib.mkOption {
      type = lib.types.port;
      default = port;
      description = "Port for the restic REST server";
    };
  };

  config = lib.mkIf cfg.enable {
    services.restic.server = {
      enable = true;
      listenAddress = "127.0.0.1:${toString cfg.port}";
      prometheus = true;
    };
  };
}
