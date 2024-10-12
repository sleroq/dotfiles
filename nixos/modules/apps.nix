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
  ];

  # For samba and other stuff
  services.gvfs.enable = true;

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  programs.noisetorch.enable = true;
  programs.java.enable = true;
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
  };

  programs.partition-manager.enable = true;

  # programs.adb.enable = true; # Phone debuggin stuff

  programs.dconf.enable = true; # Backend for gtk settings or something like that
}
