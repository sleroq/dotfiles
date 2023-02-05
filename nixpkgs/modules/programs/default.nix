{ config, pkgs, ... }:

with config;
{
  imports = [
    ./tmux.nix
    ./lf.nix
    ./zathura.nix
    ./kitty.nix
  ];

  services.flameshot.enable = true;
  services.safeeyes.enable = true;
  services.kdeconnect.enable = true;
  services.keepassxc.enable = true;

  home.packages = with pkgs; [
    tdesktop
    discord
    schildichat-desktop
    chromium
    exodus
    krita
    gimp
    libreoffice-fresh
    mpv
    obs-studio
    networkmanager-openvpn
    qbittorrent

    # CLI
    thefuck
    gocryptfs
    stow
    xclip
    onefetch
    bpytop
    bore
    ngrok
    neofetch

    # Work
    skypeforlinux
    remmina
    nomachine-client
    rustdesk
  ];
}
