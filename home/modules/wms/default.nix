{ pkgs, ... }:

{
  imports = [
    ./wayland/default.nix
    ./x11/default.nix
  ];

  # Packages universal for all window managers
  home.packages = with pkgs; [
    networkmanagerapplet # TODO: Find better solution
    pavucontrol # TODO: Find better volume control
    gammastep # screen temperature
    libnotify
    glib # gsettings
    pulseaudioFull

    # Theming
    lxappearance
    qt5ct

    dracula-theme # gtk theme
    kora-icon-theme
    libsForQt5.breeze-qt5 # qt theme
  ];

  services.gammastep = {
    enable = true;
    temperature = {
      day = 5000;
      night = 4000;
    };
    provider = "manual";
    latitude = 43.2;
    longitude = 76.8;
    tray = true;
  };
}

