{ pkgs, lib, opts, pkgs-unstable, ... }:

with lib;
{
  home.activation.kitty = hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
        ${opts.realConfigs}/kitty $HOME/.config
  '';

  fonts.fontconfig.enable = true;
  home.packages = [
    pkgs.kitty
    pkgs-unstable.nerd-fonts.jetbrains-mono
  ];
}
