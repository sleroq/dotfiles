{ pkgs, opts, lib, ... }:

with lib;
{
  imports = [
    ./sway.nix
    # ./hyprland.nix
  ];

  # Packages universal for all window managers
  home.packages = with pkgs; [
    cava
    grim
    slurp

    waypaper
    swww

    # lxappearence won't work without GDK_BACKEND=x11
    # so waiting for nwg-look package or lxappearence fix
    # nwg-look 
  ];

}
