{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    git
    neovim
    helix
    wget
    curl
    foot
    librewolf
    networkmanager-openvpn

    libsForQt5.polkit-kde-agent
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
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    # dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    gamescopeSession.enable = true;
  };

  # programs.adb.enable = true; # Phone debuggin stuff

  programs.dconf.enable = true; # Backend for gtk settings or something like that
}
