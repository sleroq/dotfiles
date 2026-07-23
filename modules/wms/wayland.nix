{ pkgs, inputs', lib, ... }:
{
  services.dbus.enable = true;
  environment.systemPackages = with pkgs; [
    dbus
    brightnessctl
  ];

  xdg.portal = {
    enable = true;
    wlr.enable = lib.mkForce false;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  programs.xwayland.enable = true;

  programs.sway.enable = true;

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    package = inputs'.hyprland.packages.hyprland;
    # portalPackage = inputs'.hyprland.packages.xdg-desktop-portal-hyprland;
  };

  # The pinned Hyprland predates its fix for dropping CAP_SYS_NICE. Without
  # this, the NixOS wrapper leaks the capability to child apps and bwrap exits.
  security.wrappers.Hyprland.capabilities = lib.mkForce "";
}
