{
  pkgs,
  inputs,
  lib,
  ...
}:
{
  nixpkgs.overlays = [
    inputs.hyprland.overlays.hyprland-packages
    inputs.hyprland.overlays.hyprland-extras
    (
      final: prev:
      lib.genAttrs [
        "aquamarine"
        "hyprcursor"
        "hyprgraphics"
        "hyprlang"
        "hyprland-guiutils"
        "xdg-desktop-portal-hyprland"
      ] (name: prev.${name}.override { stdenv = final.gcc16Stdenv; })
      // {
        glaze-hyprland = prev.glaze-hyprland.overrideAttrs {
          version = "7.2.0";
          src = inputs.glaze;
        };
      }
    )
  ];

  services.dbus.enable = true;
  environment.systemPackages = with pkgs; [
    dbus
    brightnessctl
  ];

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  programs.xwayland.enable = true;

  programs.sway.enable = true;

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    package = pkgs.hyprland;
    portalPackage = pkgs.xdg-desktop-portal-hyprland;
  };
}
