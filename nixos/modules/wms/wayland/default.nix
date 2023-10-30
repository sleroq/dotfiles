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
    extraPortals = [
      # TODO: Figure out what each portal does
      pkgs.xdg-desktop-portal-wlr
      pkgs.xdg-desktop-portal-gtk # gtk portal needed to make gtk apps happy
      pkgs.xdg-desktop-portal
    ];
  };

  security.pam.services.swaylock = {
    text = ''
      auth include login
    '';
  };

  # Brightness cli tool
  programs.light.enable = true;

  environment.systemPackages = with pkgs; [
    xdg-utils
    capitaine-cursors
    wl-clipboard
    xwayland
  ];
}
