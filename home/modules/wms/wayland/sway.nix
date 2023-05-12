{ pkgs, opts, lib, ... }:

with lib;
{
  imports = [
    ../../programs/mako.nix
    ../../programs/wofi.nix
  ];

  home.activation.sway = hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
        ${opts.realConfigs}/sway $HOME/.config
  '';

  programs.waybar.enable = true;

  home.packages = with pkgs; [
    cliphist
  ];
}
