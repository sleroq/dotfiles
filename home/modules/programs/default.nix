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

  programs.obs-studio = {
    enable = true;
    plugins = with pkgs; [
      obs-studio-plugins.obs-backgroundremoval
    ];
  };

  home.packages = with pkgs; [
    appimage-run
    # obinskit # proprietary keyboard software

    brave
    chromium

    monero-gui

    # telegram-desktop
    signal-desktop
    teamspeak-client
    
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
    qbittorrent
    keepassxc
    syncplay

    xournalpp

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
    # nomachine-client
    # rustdesk

    # gephi - Visualizing and exploring networks
    # activitywatch
    # aw-watcher-afk
    # aw-watcher-window
  ];
}
