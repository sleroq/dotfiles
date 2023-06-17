{ pkgs, ... }:

{
  imports = [
    ./tmux.nix
    ./lf.nix
    ./zathura.nix
    ./kitty.nix
    ./neofetch.nix
    ./mpv.nix
  ];

  services.flameshot.enable = true;

  nixpkgs.config.permittedInsecurePackages = [
    "electron-13.6.9"
  ];

  home.packages = with pkgs; [
    appimage-run
    obinskit

    # tor-browser-bundle-bin
    # feishin waiting for merge request to be accepted
    picard
    rclone
    tdesktop
    discord
    schildichat-desktop
    chromium
    exodus
    krita
    gimp
    libreoffice-fresh
    libsForQt5.kdenlive
    obs-studio
    networkmanager-openvpn
    qbittorrent
    keepassxc
    syncplay
    rustdesk

    ffmpegthumbnailer
    cinnamon.nemo-with-extensions

    # CLI
    gdb
    gocryptfs
    xclip
    bore-cli
    ngrok
    ffmpeg

    # Work
    skypeforlinux
    remmina
    nomachine-client

    iw
  ];
}
