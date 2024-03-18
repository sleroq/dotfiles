{ pkgs, inputs, lib, opts, ... }:

with lib; {
  imports = [
    ../../programs/mako.nix
    ../../programs/wofi.nix
  ];

  home.activation.waybar = hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
        ${opts.realConfigs}/waybar $HOME/.config
  '';

  programs.waybar = {
    enable = false;
    package = pkgs.waybar-hyprland;
  };

  home.activation.hyprland = hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
        ${opts.realConfigs}/hypr $HOME/.config
  '';
}
