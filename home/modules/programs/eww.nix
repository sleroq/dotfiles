{ pkgs, pkgs-unstable, lib, opts, ... }:

with lib;
{
  home.activation.eww = hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
        ${opts.realConfigs}/eww $HOME/.config
  '';

  fonts.fontconfig.enable = true;
  home.packages = with pkgs; [
    eww
    gawk
    pamixer
    killall

    pkgs-unstable.nerd-fonts.noto
    pkgs-unstable.nerd-fonts.daddy-time-mono
  ];
}
