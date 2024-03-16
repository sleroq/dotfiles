{ pkgs, opts, lib, ... }:

let
  # bash script to let dbus know about important env variables and
  # propagate them to relevent services run at the end of sway config
  # see
  # https://github.com/emersion/xdg-desktop-portal-wlr/wiki/"It-doesn't-work"-Troubleshooting-Checklist
  # note: this is pretty much the same as  /etc/sway/config.d/nixos.conf but also restarts
  # some user services to make sure they have the correct environment variables
  dbus-sway-environment = pkgs.writeTextFile {
    name = "dbus-sway-environment";
    destination = "/bin/dbus-sway-environment";
    executable = true;

    text = ''
      dbus-update-activation-enviroment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=sway
      systemctl --user stop pipewire pipewire-media-session xdg-desktop-portal xdg-desktop-portal-wlr systemctl --user start pipewire pipewire-media-session xdg-desktop-portal xdg-desktop-portal-wlr
    '';
  };

  # currently, there is some friction between sway and gtk:
  # https://github.com/swaywm/sway/wiki/GTK-3-settings-on-Wayland
  # the suggested way to set gtk settings is with gsettings
  # for gsettings to work, we need to tell it where the schemas are
  # using the XDG_DATA_DIR environment variable
  # run at the end of sway config
  configure-gtk = pkgs.writeTextFile {
    name = "configure-gtk";
    destination = "/bin/configure-gtk";
    executable = true;
    text = let
      schema = pkgs.gsettings-desktop-schemas;
      datadir = "${schema}/share/gsettings-schemas/${schema.name}";
    in ''
      export XDG_DATA_DIRS=${datadir}:$XDG_DATA_DIRS
      gnome_schema=org.gnome.desktop.interface
      gsettings set $gnome_schema gtk-theme 'Breeze-Dark'
    '';
  };

  sway-wrapper = pkgs.writeScriptBin "sway-wrapper" ''
    #!/bin/sh
    export _JAVA_AWT_WM_NONREPARENTING=1;
    export XDG_SESSION_TYPE=wayland;
    export QT_QPA_PLATFORM=wayland;
    export QT_QPA_PLATFORMTHEME=qt6ct;
    export QT_WAYLAND_DISABLE_WINDOWDECORATION=1;
    export CLUTTER_BACKEND=wayland;
    export SDL_VIDEODRIVER=wayland;
    export MOZ_ENABLE_WAYLAND=1;
    export VDPAU_DRIVER=radeonsi;

    exec sway
  '';
in
with lib; {
  imports = [
    ../../programs/wofi.nix
    ../../programs/eww.nix
    ../../programs/swaync.nix
  ];

  home.activation.sway = hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
        ${opts.realConfigs}/sway/* $HOME/.config/sway/
  '';

  programs = {
    # waybar.enable = true;
    swaylock.enable = true;
  };

  services = {
    swayidle.enable = true;
    swayosd.enable = true;
    cliphist.enable = true;
  };

  wayland.windowManager.sway = {
    enable = true;
    package = pkgs.swayfx;

    # This probably does nothing
    wrapperFeatures.gtk = true;
    wrapperFeatures.base = true;

    # Not writing my config directly, to be able edit it without rebuilding
    config = null;
    extraConfig = ''
      include main-config
    '';
  };

  home.packages = with pkgs; [
    configure-gtk
    dbus-sway-environment
    sway-wrapper

    stalonetray
    cliphist
    swayidle
    swaykbdd
    swayr
  ];
}
