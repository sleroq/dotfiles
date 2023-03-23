{ config, pkgs, opts, lib, ... }:

with lib;
with config;
{
  imports = [
    ./leftwm.nix
    ./sway.nix
  ];

  home.activation.picom = hm.dag.entryAfter ["writeBoundary"] ''
    $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
        ${opts.realConfigs}/picom.conf $HOME/.config
  '';

  home.packages = with pkgs; [
    networkmanagerapplet
    ulauncher
    picom
  ];
}
