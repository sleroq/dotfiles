# This direcotry is meant for configurations relevant on every host

{ pkgs, inputs', lib, config, self, ... }:

{
  imports = [
    ./git.nix
    ./theming.nix
    ./wms.nix
    (import ../shared/shell.nix { inherit pkgs self; enableSshAuthSocket = false; })
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
        version = "0.53.3-alpha";
        hash = "sha256-bACau7UauGPULWkEwb1E7vUhgw4YAg5eDibjR2L21sk=";
      };
      helium = {
        enable = true;
        version = "0.7.9.1";
        hash = "sha256-69y8dNJPJk+HgnLzkyYLMdps1Med65yeN+77Nk6jbyM=";
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

    development = {
      enable = true;
    };
  };

  xsession.enable = true;

  services.syncthing.enable = true;

  programs.home-manager.enable = true;
}
