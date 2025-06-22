{ config, pkgs, lib, ... }:
let
  cfg = config.cumserver.podman;
in
{
  options.cumserver.podman.enable = lib.mkEnableOption "Podman container runtime";

  config = lib.mkIf cfg.enable {
    # Enable Podman with proper rootless configuration
    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
      
      # Enable auto-pruning to keep storage clean
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };

    # Add podman-compose to system packages
    environment.systemPackages = with pkgs; [
      podman-compose
    ];
  };
} 