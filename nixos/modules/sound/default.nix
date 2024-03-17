{ config, pkgs, lib, ... }:
{
  # Enable sound with Pipewire.
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  environment.systemPackages = with pkgs; [
    # Real-time audio patcher
    helvum
  ];
}
