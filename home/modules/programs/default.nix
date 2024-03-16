{ pkgs, ... }:

{
  imports = [
    ./lf.nix
    ./zathura.nix
    ./foot.nix
    ./neofetch.nix
    ./mpv.nix
    ./tmux.nix
  ];

  nixpkgs.config.permittedInsecurePackages = [
    "electron-13.6.9" # Required for obinskit
    "electron-25.9.0" # Required by obsidian
  ];

  home.packages = with pkgs; [
    appimage-run
    obinskit # proprietary keyboard software
    nheko
    parsec-bin

    tor-browser-bundle-bin
    picard # music tagger
    telegram-desktop
    discord-screenaudio
    chromium
    thunderbird
    exodus
    krita
    obsidian
    anytype-beta
    libreoffice-fresh
    libsForQt5.kdenlive
    obs-studio
    qbittorrent
    keepassxc
    syncplay

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
    rustdesk

    iw

    # activitywatch
    # aw-watcher-afk
    # aw-watcher-window
  ];
}
