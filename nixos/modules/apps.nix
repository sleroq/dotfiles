{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    git
    neovim
    wget
    curl
    foot
    librewolf
    nvtopPackages.full
    powertop
  ];

  # For samba and other stuff
  services.gvfs.enable = true;

  # Steam remote play
  hardware.uinput.enable = true;

  programs = {
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
      ];
    };

    gamescope = {
      enable = true;
      capSysNice = true;
    };

    gamemode.enable = true;

    partition-manager.enable = true;

    dconf.enable = true;

    fuse.userAllowOther = true;

    noisetorch.enable = true;

    adb.enable = true; # Phone debuggin stuff
  };


  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
    rulesProvider = pkgs.ananicy-cpp;
    extraRules = [
      {
        "name" = "gamescope";
        "nice" = -20;
      }
    ];
  };
}
