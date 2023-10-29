{ pkgs, ... }:

{
  imports = [ ./osu.nix ];

  home.packages = with pkgs; [
    # lutris
    gamemode
    wine64Packages.stagingFull

    prismlauncher-qt5
  ];
}
