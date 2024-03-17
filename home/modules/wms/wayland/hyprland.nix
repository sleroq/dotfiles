{ pkgs, inputs, lib, opts, ... }:

with lib; {
  imports = [
    inputs.hyprland.homeManagerModules.default
    ../../programs/mako.nix
    ../../programs/wofi.nix
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    # FIXME: , I wanted config path to be configurable with opts.realConfigs
    # I need to either change this approach or figure out how to make it count as "pure".
    # It can read "username" from file in nixos/ configuration, but it can't read config file there.
    extraConfig = (builtins.readFile ../../config/hypr/hyprland.conf);
    recommendedEnvironment = true;
  };

  home.activation.waybar = hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
        ${opts.realConfigs}/waybar $HOME/.config
  '';

  programs.waybar = {
    enable = true;
    package = pkgs.waybar-hyprland;
  };

  home.activation.hyprland = hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
      ${opts.realConfigs}/hypr/autostart.bash $HOME/.config/hypr/
  '';
}
