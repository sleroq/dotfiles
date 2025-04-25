{ inputs, pkgs, pkgs-unstable, ... }:

{
  home.packages = with inputs.nix-gaming.packages.${pkgs.system}; [
    osu-lazer-bin
    # osu-stable
    pkgs.opentabletdriver
    pkgs.protonup-qt
    pkgs-unstable.prismlauncher
  ];
}
