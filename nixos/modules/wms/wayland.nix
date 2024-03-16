{ pkgs, ... }: {
  # xdg-desktop-portal works by exposing a series of D-Bus interfaces
  # known as portals under a well-known name
  # (org.freedesktop.portal.Desktop) and object path
  # (/org/freedesktop/portal/desktop).
  # The portal interfaces include APIs for file access, opening URIs,
  # printing and others.
  services.dbus.enable = true;

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    configPackages = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal # For sandboxed apps
      xdg-desktop-portal-gtk # I don't know what it does but won't hurt
      xdg-desktop-portal-shana # For file picker
    ];
  };

  security.pam.services.swaylock = {
    text = ''
      auth include login
    '';
  };

  # Brightness cli tool
  programs.light.enable = true;
  programs.xwayland.enable = true;

  environment.systemPackages = with pkgs; [
    swayfx
  ];

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraSessionCommands = ''
      export _JAVA_AWT_WM_NONREPARENTING=1;
      export XDG_SESSION_TYPE=wayland;
      export QT_QPA_PLATFORM=wayland;
      export QT_QPA_PLATFORMTHEME=qt6ct;
      export QT_WAYLAND_DISABLE_WINDOWDECORATION=1;
      export CLUTTER_BACKEND=wayland;
      export SDL_VIDEODRIVER=wayland;
      export MOZ_ENABLE_WAYLAND=1;
      export VDPAU_DRIVER=radeonsi;
      export TESTVARKEK=1;

      dbus-sway-environment
      configure-gtk
    '';
  };
}
