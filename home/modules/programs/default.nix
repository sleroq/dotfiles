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
    "electron-13.6.9"
  ];

  home.packages = with pkgs; [
    appimage-run
    obinskit # proprietary keyboard software

    tor-browser-bundle-bin
    # feishin waiting for merge request to be accepted
    picard # music tagger
    tdesktop
    discord
    nheko
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
    scrcpy # android screen mirroring

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
    ngrok
    ffmpeg

    # Work
    skypeforlinux
    remmina
    nomachine-client

    iw

    activitywatch
    aw-watcher-afk
    aw-watcher-window
  ];
}
