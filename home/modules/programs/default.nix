{ pkgs, inputs, ... }:

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
    # "electron-13.6.9" # Required for obinskit
    "electron-25.9.0" # Required by obsidian
  ];

  home.packages = with pkgs; [
    appimage-run
    # obinskit # proprietary keyboard software

    brave

    monero-gui

    telegram-desktop
    signal-desktop
    vesktop
    discord-screenaudio
    nheko
    iamb
    
    inputs.paisa.packages.${pkgs.system}.default
    ledger
    beancount
    beancount-language-server
    fava

    libsForQt5.kate
    obsidian
    (callPackage ../../packages/anytype.nix {})

    picard # music tagger
    nomacs # image viewer
    thunderbird
    krita
    libreoffice-fresh
    kdePackages.kdenlive
    obs-studio
    qbittorrent
    keepassxc
    # syncplay

    # File manager
    ffmpegthumbnailer
    lxqt.pcmanfm-qt
    dolphin

    # For "Choose Application" inside pcmanfm-qt to work
    lxqt.lxqt-menu-data
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
    zellij
    # rustdesk

    # gephi - Visualizing and exploring networks
    # activitywatch
    # aw-watcher-afk
    # aw-watcher-window
  ];
}
