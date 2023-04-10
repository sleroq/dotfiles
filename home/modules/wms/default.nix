{ config, pkgs, opts, lib, ... }:

with lib;
with config;
{
  imports = [
    # ./leftwm.nix
    # ./sway.nix
  ];

  home.activation.picom = hm.dag.entryAfter ["writeBoundary"] ''
    $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
        ${opts.realConfigs}/picom.conf $HOME/.config
  '';

  services.gammastep = {
    enable = true;
    temperature = {
      day = 5000;
      night = 4000;
    };
    provider = "manual";
    latitude = 43.2;
    longitude = 76.8;
    tray = true;
  };

  home.packages = with pkgs; [
    networkmanagerapplet
    ulauncher
    picom
    pavucontrol
    gammastep       # screen temperature
  ];
}
