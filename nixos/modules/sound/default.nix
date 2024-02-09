{ config, pkgs, lib, ... }:
{
  imports = [
    ./pipewire-low-latency.nix
  ];

  # Enable sound with Pipewire.
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    lowLatency = {
      enable = true;
      quantum = 64;
      rate = 48000;
    };
  };

  environment.systemPackages = with pkgs; [
    # Real-time audio patcher
    helvum
  ];
}
