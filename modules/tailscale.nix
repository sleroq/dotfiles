{ config, pkgs, lib, ... }:
let
  cfg = config.sleroq.tailscale;
in
{
  options.sleroq.tailscale.enable = lib.mkEnableOption "tailscale";

  config = lib.mkIf cfg.enable {
    services.tailscale.enable = true;
    networking.firewall = {
      enable = true;
      trustedInterfaces = [ "tailscale0" ];
      allowedUDPPorts = [ config.services.tailscale.port ];
    };

    environment.systemPackages = [
      pkgs.tailscale
    ];
  };
}
