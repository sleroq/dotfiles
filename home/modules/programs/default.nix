{ pkgs, pkgs-old, ... }:

{
  imports = [
    ./lf.nix
    ./zathura.nix
    ./foot.nix
    # ./neofetch.nix
    ./mpv.nix
    # ./tmux.nix
    ./ghostty.nix
  ];

  programs.obs-studio = {
    enable = true;
    plugins = with pkgs; [
      obs-studio-plugins.obs-backgroundremoval
    ];
  };

  home.packages = with pkgs; [
    chromium

    exodus
    monero-gui

    # feishin
    # signal-desktop
    
    # inputs.paisa.packages.${pkgs.system}.default
    # ledger
    # beancount
    # beancount-language-server
    # fava

    teamspeak5_client
    syncplay

    pkgs-old.obinskit

    keepassxc
    krita
    libreoffice-fresh
    xournalpp
    # obsidian
    (callPackage ../../packages/anytype.nix {})
    picard # music tagger
    qbittorrent
    # thunderbird

    nemo
    kdePackages.ark # TODO: this is for noobs (or is it)
    kdePackages.filelight
    p7zip
    unzip
    nomacs # Image viewer

    # CLI
    rclone
    gdb
    # gocryptfs
    # xclip
    # bore-cli
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
