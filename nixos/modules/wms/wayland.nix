{ pkgs, inputs, lib, ... }:
{
  # xdg-desktop-portal works by exposing a series of D-Bus interfaces
  # known as portals under a well-known name
  # (org.freedesktop.portal.Desktop) and object path
  # (/org/freedesktop/portal/desktop).
  # The portal interfaces include APIs for file access, opening URIs,
  # printing and others.
  services.dbus.enable = true;

  xdg.portal = {
    enable = true;
    wlr.enable = lib.mkForce false;
    # extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Brightness cli tool
  programs.light.enable = true;
  programs.xwayland.enable = true;

  environment.systemPackages = with pkgs; [
    dbus # make dbus-update-activation-environment available in the path
  ];

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  };
}
