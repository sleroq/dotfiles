{ config, pkgs, ... }:

with config;
{
  imports = [ ./tmux.nix ];

  home.packages = with pkgs; [
    tdesktop
    discord
    schildichat-desktop
    keepassxc
    flameshot
    chromium
    exodus
    krita
    obs-studio
    mpv
    networkmanager-openvpn
    qbittorrent
    safeeyes
    kitty

    # CLI
    thefuck
    gocryptfs
    stow
    xclip
    onefetch
    bpytop
    bore
    ngrok

    # Work
    skypeforlinux
    remmina
    nomachine-client
    rustdesk
  ];
}
