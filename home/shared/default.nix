# This direcotry is meant for configurations relevant on every host

{ pkgs, inputs, ... }:

{
  imports = [
    ./git.nix
    ./theming.nix
    ./wms.nix
    ./shell.nix
    ./development.nix
  ];

  home.username = "sleroq";
  home.homeDirectory = "/home/sleroq";

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
      anytype = {
        enable = true;
        version = "0.47.3";
        hash = "sha256-19VHCezNqWAgkw+5RlvZ31gSiHKPVhHvpRVlifJ9K88=";
      };
      mpv.enable = true;
      foot = {
        enable = true;
        default = true;
      };

      extraPackages = with pkgs; [
        exodus
        monero-gui

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

        hiddify-app
        inputs.agenix.packages.${pkgs.system}.default
      ];
    };
  };

  xsession.enable = true;

  services.syncthing.enable = true;

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "22.11";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  nixpkgs.config.allowUnfreePredicate = (_: true);
}
