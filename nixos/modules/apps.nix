{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    git
    neovim
    wget
    curl
    foot
    librewolf
    networkmanager-openvpn
    nekoray
    nvtopPackages.full
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

    java.enable = true;

    steam = {
      enable = true;
      extest.enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
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

    # adb.enable = true; # Phone debuggin stuff
  };
}
