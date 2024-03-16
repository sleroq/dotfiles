{ pkgs, ... }: {
  # xdg-desktop-portal works by exposing a series of D-Bus interfaces
  # known as portals under a well-known name
  # (org.freedesktop.portal.Desktop) and object path
  # (/org/freedesktop/portal/desktop).
  # The portal interfaces include APIs for file access, opening URIs,
  # printing and others.
  services.dbus.enable = true;

  services.xserver.displayManager.session = [
    {
      manage = "desktop";
      name = "sway-session";
      start = ''
        sway-wrapper &
        waitPID=$!
      '';
    }
  ];

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    configPackages = [ pkgs.xdg-desktop-portal-kde pkgs.xdg-desktop-portal ];
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
    xwayland
  ];
}
