{ pkgs, pkgs-old, inputs, ... }:

{
  imports = [
    ./lf.nix
    ./zathura.nix
    ./foot.nix
    ./neofetch.nix
    ./mpv.nix
    ./tmux.nix
  ];

  programs.obs-studio = {
    enable = true;
    plugins = with pkgs; [
      obs-studio-plugins.obs-backgroundremoval
    ];
  };

  home.packages = with pkgs; [
    brave
    chromium

    # exodus # Does not work

    # monero-gui
    signal-desktop
    
    # inputs.paisa.packages.${pkgs.system}.default
    # ledger
    # beancount
    # beancount-language-server
    # fava

    libsForQt5.kate
    obsidian
    (callPackage ../../packages/anytype.nix {})
    pkgs-old.obinskit

    picard # music tagger
    nomacs # image viewer
    thunderbird
    krita
    libreoffice-fresh
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

    timeshift

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
