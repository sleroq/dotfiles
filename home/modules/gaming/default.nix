{ pkgs, ... }:

{
  imports = [
    ./osu.nix
  ];


  home.packages = with pkgs; [
    # lutris
    # gamemode
    prismlauncher
  ];
}
