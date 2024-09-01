{ pkgs, ... }:

{

  imports = [
    ./wayland/default.nix
    # ./x11/default.nix
  ];

  services.flameshot = {
    enable = true;
    # package = pkgs.flameshot.override { enableWlrSupport = true; };
  };

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
    kdePackages.qt6ct
    kdePackages.qtstyleplugin-kvantum
    catppuccin-kvantum
    kora-icon-theme

    kdePackages.breeze-gtk
    lxqt.lxqt-config
    zuki-themes

    kdePackages.breeze
    catppuccin-qt5ct
    lxqt.lxqt-themes
    libsForQt5.kiconthemes
    libsForQt5.grantleetheme
    libsForQt5.qtstyleplugins
    libsForQt5.lightly
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
