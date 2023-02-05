{ config, pkgs, ... }:

with config;
{
  imports = [
    ./tmux.nix
    ./lf.nix
  ];

  services.flameshot.enable = true;

  home.packages = with pkgs; [
    tdesktop
    discord
    schildichat-desktop
    keepassxc
    chromium
    exodus
    krita
    gimp
    libreoffice-fresh
    mpv
    obs-studio
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
