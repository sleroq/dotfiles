{ config, pkgs, ... }:

with config;
{
  imports = [ ./leftwm.nix ];
  home.packages = with pkgs; [
    networkmanagerapplet
  ];
}
