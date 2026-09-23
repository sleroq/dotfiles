{
  lib,
  config,
  pkgs,
  flakeRoot,
  ...
}:
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
      # nvtopPackages.full
      powertop
    ];

    # For samba and other stuff
    services.gvfs.enable = true; # what is this and why do I need samba?

    # Steam remote play
    hardware.uinput.enable = true;

    programs = {
      nh = {
        enable = true;
        flake = flakeRoot;
      };
      neovim = {
        enable = true;
        defaultEditor = true;
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
      dconf.enable = true; # required by easyeffects and some other stuff
      fuse.userAllowOther = true; # why do I need this
      noisetorch.enable = true;
    };

    # A running gamemoded can temporarily reference the previous Nix store path
    # after a system switch. Polkit then misses GameMode's path-specific actions
    # and falls back to org.freedesktop.policykit.exec, causing password prompts.
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        var program = action.lookup("program");
        var gamemodeHelper = /^\/nix\/store\/[a-z0-9]{32}-gamemode-[^/]+\/libexec\/(cpugovctl|gpuclockctl|cpucorectl|procsysctl)$/;

        if (action.id == "org.freedesktop.policykit.exec" &&
            subject.isInGroup("gamemode") &&
            program && gamemodeHelper.test(program)) {
          return polkit.Result.YES;
        }
      });
    '';

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
