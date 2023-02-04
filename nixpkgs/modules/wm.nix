{ config, pkgs, ... }:

with config;
{
  home.packages = with pkgs; [
    networkmanagerapplet
  ];
}
