{ pkgs, ... }:

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
    text =
      let
        schema = pkgs.gsettings-desktop-schemas;
        datadir = "${schema}/share/gsetting-schemas/${schema.name}";
      in
      ''
        export XDG_DATA_DIRS=${datadir}:$XDG_DATA_DIRS
        gnome_schema=org.gnome.desktop.interface
        gsettings set $gnome_schema gtk-theme 'Breeze-Dark'
      '';
  };
in
{
  imports = [
    ./sway.nix
    ./hyprland.nix
    ./dwl/default.nix
  ];

  services.kanshi.enable = true;

  programs.tofi = {
    enable = true;
    settings = {
      background-color = "#000A";
      border-width = 0;
      font = "monospace";
      height = "100%";
      num-results = 5;
      outline-width = 0;
      padding-left = "35%";
      padding-top = "35%";
      result-spacing = 25;
      width = "100%";
    };
  };

  # Packages universal for all window managers
  home.packages = with pkgs; [
    configure-gtk

    wl-clipboard
    cliphist
    # cava
    grim
    slurp

    waypaper
    swww

    nwg-look
  ];

}
