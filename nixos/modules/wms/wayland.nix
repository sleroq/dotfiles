{ pkgs, inputs, lib, ... }:
{
  services.dbus.enable = true;
  environment.systemPackages = with pkgs; [
    dbus
  ];

  xdg.portal = {
    enable = true;
    wlr.enable = lib.mkForce false;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Brightness cli tool
  programs.light.enable = true;
  programs.xwayland.enable = true;

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  };
}
