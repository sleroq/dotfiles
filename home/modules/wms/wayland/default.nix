{ pkgs, pkgs-unstable, ... }:
{
  imports = [
    # ./sway.nix
    ./hyprland.nix
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
    wl-clipboard
    cliphist
    # cava
    grim
    slurp

    waypaper
    swww

    nwg-look
    # pkgs-unstable.nwg-displays # TODO: Make stable after major update
  ];
}
