{ pkgs, opts, lib, ... }:

let
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
      gnome_schema=org.gnome.desktop.interface
      gsettings set $gnome_schema gtk-theme 'Breeze-Dark'
    '';
  };
in 
with lib; {
  imports = [
    ./sway.nix
    ./hyprland.nix
  ];

  services.kanshi.enable = true;

  # Packages universal for all window managers
  home.packages = with pkgs; [
    configure-gtk

    wl-clipboard
    cava
    grim
    slurp

    waypaper
    swww

    nwg-look 
  ];

}
