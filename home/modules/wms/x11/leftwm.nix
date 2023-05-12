{ config, pkgs, opts, lib, ... }:

with config;
with lib;
{
  home.activation.leftwm = hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
        ${opts.realConfigs}/leftwm $HOME/.config
  '';

  home.packages = with pkgs; [
    xss-lock
    rofi
    alsa-utils

    xorg.xbacklight
    sct

    # Screen-locking:
    slock
    i3lock
    maim
    imagemagick
  ];
}
