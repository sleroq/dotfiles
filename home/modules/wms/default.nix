{ config, pkgs, ... }:

with config;
{
  imports = [
    ./leftwm.nix
    ./sway.nix
  ];
  home.packages = with pkgs; [
    networkmanagerapplet
  ];
}
