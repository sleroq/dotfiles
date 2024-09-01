{ pkgs, inputs, lib, ... }:

let
  waylandBaseSession = ''
    export _JAVA_AWT_WM_NONREPARENTING=1;
    export XDG_SESSION_TYPE=wayland;
    # export QT_QPA_PLATFORM=wayland;
    export QT_QPA_PLATFORMTHEME=qt6ct;
    export QT_WAYLAND_DISABLE_WINDOWDECORATION=1;
    export CLUTTER_BACKEND=wayland;
    export SDL_VIDEODRIVER=wayland;
    export MOZ_ENABLE_WAYLAND=1;
    export VDPAU_DRIVER=radeonsi;
    export NIXOS_OZONE_WL=1;
  '';
in 
{
  imports = [
    # (import ./dwl)
  ];
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
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Brightness cli tool
  programs.light.enable = true;
  programs.xwayland.enable = true;

  environment.systemPackages = with pkgs; [
    dbus # make dbus-update-activation-environment available in the path
    (swayfx.override {
      # TODO: Figure out why can't I pass extraSessionCommands in programs.sway... options
      extraSessionCommands = waylandBaseSession;
    })
  ];

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };

  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.system}.hyprland;
  };

  };

  # programs.dwl = {
  #   enable = true;
  #   postPatch =
  #     let
  #       configFile = ./dwl/dwl-config.h; # TODO: move somewhere else
  #     in
  #     ''
  #       cp ${configFile} config.def.h
  #     '';
  # };
}
