{ lib, config, pkgs, inputsResolved', ... }:
with lib;
let
  cfg = config.sleroq.apps;
in
{
  options.sleroq.apps.enable = mkEnableOption "desktop apps and related services";

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      git
      neovim
      wget
      curl
      nvtopPackages.full
      powertop
      inputsResolved'.zenbrowser.packages.default
    ];

    # For samba and other stuff
    services.gvfs.enable = true; # what is this and why do I need samba?

    # Steam remote play
    hardware.uinput.enable = true;

    programs = {
      nh = {
        enable = true;
        flake = "/home/sleroq/develop/other/dotfiles"; # TODO: infer from args
      };
      neovim = {
        enable = true;
        defaultEditor = true;
        viAlias = true;
        vimAlias = true;
      };

      steam = {
        enable = true;
        extest.enable = true;
        remotePlay.openFirewall = true;
        dedicatedServer.openFirewall = true;
        localNetworkGameTransfers.openFirewall = true;
        extraPackages = with pkgs; [
          gamescope
          mangohud
        ];
      };

      gamescope = {
        enable = true;
        # capSysNice = true; # breaks gamescope?
      };

      gamemode.enable = true;
      dconf.enable = true;
      fuse.userAllowOther = true; # why do I need this
      noisetorch.enable = true;
    };

    # services.ananicy = {
    #   enable = true;
    #   package = pkgs.ananicy-cpp;
    #   rulesProvider = pkgs.ananicy-cpp;
    #   extraRules = [
    #     {
    #       "name" = "gamescope";
    #       "nice" = -20;
    #     }
    #   ];
    # };
  };
}
