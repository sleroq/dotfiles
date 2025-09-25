{ pkgs, ... }:

{
  # Packages universal for all window managers
  home.packages = with pkgs; [
    networkmanagerapplet # TODO: Find better gui
    pwvucontrol
    coppwr
    gammastep # screen temperature
    libnotify
    glib # gsettings
    # pulseaudioFull
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
