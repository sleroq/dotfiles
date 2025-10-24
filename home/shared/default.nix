# This direcotry is meant for configurations relevant on every host

{ pkgs, inputs', lib, config, ... }:

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

  age.secrets.ssh-config = {
    file = ../secrets/ssh-config;
    path = ".ssh/config";
  };

  myHome = {
    wms.wayland = {
      enable = true;
      hyprland.enable = true;
    };

    editors = {
      # vscode.enable = true;
      neovim = {
        enable = true;
        enableNeovide = true;
        default = true;
      };
    };

    programs = {
      anytype = {
        enable = true;
        version = "0.50.17-alpha";
        hash = "sha256-uSqAjGrUJ4aptEGEtpxtW04t12MC/RVbxK5UsCm8hyI=";
      };
      helium = {
        enable = true;
        version = "0.5.7.1";
        hash = "sha256-A+fNcW7ujbeYqOb+gxzQ0p19J14csfFyok0RVRFxo60=";
      };

      mpv.enable = true;
      kitty = {
        enable = true;
        default = true;
      };

      extraPackages =
        let base = with pkgs; [
          # monero-gui
          # signal-desktop
          legcord

          # teamspeak6-client
          syncplay

          # krita
          # libreoffice-fresh
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
          # rclone
          gdb
          ffmpeg

          # Remote stuff
          # bore-cli
          remmina
          # nomachine-client
          # rustdesk
          # vial
          inputs'.agenix.packages.default
        ];
        in base ++ lib.optionals (lib.attrByPath [ "myHome" "programs" "exodus" "enable" ] false config) [ pkgs.exodus ];
    };
  };

  xsession.enable = true;

  services.syncthing.enable = true;

  programs.home-manager.enable = true;
}
