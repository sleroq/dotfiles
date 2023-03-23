
{ config, pkgs, opts, lib, ... }:

with config;
with lib;
{
  home.activation.leftwm = hm.dag.entryAfter ["writeBoundary"] ''
    $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
        ${opts.realConfigs}/leftwm $HOME/.config
  '';

#   programs.zsh = mkIf opts.zsh-integration {
#     envExtra = ''
#       path+=("${opts.realConfigs}")
#     '';
#   };

  home.packages = with pkgs; [
    xss-lock
    pavucontrol
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
