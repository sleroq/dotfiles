{ pkgs, inputs', lib, ... }:
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
  programs.light.enable = true; # TODO: make it laptop only?
  programs.xwayland.enable = true;

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    package = inputs'.hyprland.packages.hyprland;
    # portalPackage = inputs'.hyprland.packages.xdg-desktop-portal-hyprland;
  };
}
