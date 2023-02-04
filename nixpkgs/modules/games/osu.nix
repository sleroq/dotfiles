{ config, pkgs, inputs, ... }:

with config;
{
  home.packages = with inputs.nix-gaming.packages.${pkgs.system}; [
    osu-lazer-bin
    osu-stable
    pkgs.opentabletdriver
  ];
}
