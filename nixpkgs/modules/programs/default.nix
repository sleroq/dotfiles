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

  home.packages = with pkgs; [
    tdesktop
    discord
    schildichat-desktop
    chromium
    exodus
    krita
    libsForQt5.kdenlive
    ngrok
    gimp
    libreoffice-fresh
    mpv
    obs-studio
    networkmanager-openvpn
    qbittorrent
    keepassxc

    # CLI
    thefuck
    gocryptfs
    stow
    xclip
    onefetch
    bpytop
    bore-cli
    ngrok
    neofetch
    ffmpeg
    # shadowsocks-libev
    # shadowsocks-v2ray-plugin

    # Work
    skypeforlinux
    remmina
    nomachine-client
    rustdesk
  ];
}
