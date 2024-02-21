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

  services.flameshot.enable = true;
  
  nixpkgs.config.permittedInsecurePackages = [
    "electron-13.6.9" # Required for obinskit
    "electron-25.9.0" # Required by obsidian
  ];

  home.packages = with pkgs; [
    appimage-run
    obinskit # proprietary keyboard software
    xray
    nheko

    youtube-music
    sublime-music
    tor-browser-bundle-bin
    picard # music tagger
    telegram-desktop
    discord-screenaudio
    chromium
    thunderbird
    exodus
    krita
    logseq
    obsidian
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
    rustdesk

    iw

    # activitywatch
    # aw-watcher-afk
    # aw-watcher-window
  ];
}
