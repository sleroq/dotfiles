# This direcotry is meant for configurations relevant on every host

{ pkgs, inputs, ... }:

{
  imports = [
    ./git.nix
    ./theming.nix
    ./wms.nix
    ./shell.nix
    ./development.nix
    ./scripts.nix
  ];

  home = {
    username = "sleroq";
    homeDirectory = "/home/sleroq";
    stateVersion = "22.11";
  };

  myHome = {
    wms.wayland = {
      enable = true;
      hyprland.enable = true;
    };

    editors = {
      vscode = {
        enable = true;
      };
      neovim = {
        enable = true;
        enableNeovide = true;
        default = true;
      };
    };

    programs = {
      ghostty.enable = true;
      anytype = {
        enable = true;
        version = "0.47.49-beta";
        hash = "sha256-vdowq4IsEoFgNHJDShiLfnxk5AUEwNuSB8sktNU6Beo=";
      };
      mpv.enable = true;
      foot = {
        enable = true;
        default = true;
      };

      extraPackages = with pkgs; [
        exodus
        monero-gui
        signal-desktop

        teamspeak6-client
        syncplay

        krita
        libreoffice-fresh
        xournalpp
        picard # music tagger

        # obsidian
        qbittorrent
        thunderbird

        keepassxc

        nemo

        kdePackages.filelight
        p7zip
        unzip
        nomacs # Image viewer

        # CLI
        rclone
        gdb
        ffmpeg

        # Remote stuff
        # bore-cli
        remmina
        # nomachine-client
        # rustdesk
        vial
        inputs.agenix.packages.${pkgs.system}.default
      ];
    };
  };

  xsession.enable = true;

  services.syncthing.enable = true;

  programs.home-manager.enable = true;

  nixpkgs.config.allowUnfreePredicate = _: true;
}
