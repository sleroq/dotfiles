{ config, pkgs, ... }:

with config;
{
  home.packages = with pkgs; [
    lutris
    gamemode
    osu-lazer-bin
  ];
}