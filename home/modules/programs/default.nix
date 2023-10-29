{ pkgs, ... }:

{
  imports = [
    ./tmux.nix
    ./lf.nix
    ./zathura.nix
    ./foot.nix
    ./neofetch.nix
    ./mpv.nix
  ];

  services.flameshot.enable = true;
  
  nixpkgs.config.permittedInsecurePackages = [
    "electron-13.6.9" # Required for obinskit
    "electron-24.8.6" # Required by something else
  ];

  home.packages = with pkgs; [
    appimage-run
    # obinskit # proprietary keyboard software

    tor-browser-bundle-bin
    # feishin waiting for merge request to be accepted
    picard # music tagger
    discord
    schildichat-desktop
    chromium
    brave
    # exodus
    krita
    libreoffice-fresh
    libsForQt5.kdenlive
    obs-studio
    networkmanager-openvpn
    qbittorrent
    keepassxc
    syncplay

    # Android screen mirroring
    # scrcpy
    # android-tools

    ffmpegthumbnailer
    lxqt.pcmanfm-qt
    lxmenu-data
    shared-mime-info

    # CLI
    rclone
    gdb
    gocryptfs
    xclip
    bore-cli
    ffmpeg

    # Work
    remmina
    nomachine-client

    iw

    activitywatch
    aw-watcher-afk
    aw-watcher-window
  ];
}
