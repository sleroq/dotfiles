{ config, pkgs, lib, ... }:

{
  environment.systemPackages = with pkgs; [
    foot
    librewolf
    networkmanager-openvpn

    libsForQt5.polkit-kde-agent

    (steam.override {
      extraPkgs = pkgs: [ bumblebee glxinfo ];
    }).run
  ];

  # For samba and other stuff
  services.gvfs.enable = true;

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  programs.noisetorch.enable = true;
  programs.java.enable = true;
  programs.steam = {
    enable = true;
    # remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    # dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
  };

  # programs.adb.enable = true; # Phone stuff

  programs.dconf.enable = true; # Backend for gtk settings or something like that
}
