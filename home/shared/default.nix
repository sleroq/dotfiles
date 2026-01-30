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
        version = "0.53.26-alpha";
        hash = "0daapymbkq5s9qdya9g7a4ay6813n1abyfb36rva0kpdhkppqhph";
      };
      helium = {
        enable = true;
        version = "0.8.3.1";
        hash = "18xlws93x03cb0xiylfyahx31w7yb9rwyihric4n9b7s9xknss8q";
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
