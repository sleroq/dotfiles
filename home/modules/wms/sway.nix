{ config, pkgs, opts, lib, ... }:

with config;
with lib;
{
  home.activation.sway = hm.dag.entryAfter ["writeBoundary"] ''
    $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
        ${opts.realConfigs}/sway $HOME/.config
    $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
        ${opts.realConfigs}/waybar $HOME/.config
  '';

 # programs.zsh = mkIf opts.zsh-integration {
 #   envExtra = ''
 #   '';
 # };

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

  home.packages = with pkgs; [
    wayland
    xdg-utils       # for opening default programs when clicking links
    glib            # gsettings
    dracula-theme   # gtk theme
    gnome3.adwaita-icon-theme  # default gnome cursors
    swaylock
    swayidle
    grim            # screenshot functionality
    slurp           # screenshot functionality
    wl-clipboard    # wl-copy and wl-paste for copy/paste from stdin / stdout
    mako            # notification system developed by swaywm maintainer
    waybar
    wofi
    pulseaudioFull
    gammastep       # screen temperature
    lxappearance
    qt5ct
  ];
}
