{ pkgs, ... }: {
  services.xserver.excludePackages = [ pkgs.xterm ];

  # Enable the X11 windowing system.
  services.xserver = {
    enable = true;
    windowManager.leftwm.enable = true;
  };

  # Configure keymap in X11
  services.xserver = {
    layout = "us";
    xkbVariant = "";
  };
}
