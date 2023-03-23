{ config, pkgs, lib, ... }:

{
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    networkmanager-openvpn
    kitty
    firefox
    cloudflare-warp

    # For XFCE
    xfce.xfce4-xkb-plugin
    xfce.xfce4-systemload-plugin
  ];

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
    # remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    # dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
  };

  systemd.services.warp-svc = {
    wantedBy = [ "multi-user.target" ]; 
    after = [ "network.target" ];
    description = "Start cloudflare warp service";
    serviceConfig = {
      # Type = "forking";
      # User = "sleroq";
      ExecStart = ''${pkgs.cloudflare-warp}/bin/warp-svc'';         
      # ExecStop = ''${pkgs.screen}/bin/screen -S irc -X quit'';
     };
  };

  virtualisation.virtualbox.host.enable = true;
  virtualisation.virtualbox.host.enableExtensionPack = true;
  virtualisation.virtualbox.guest.enable = true;
  virtualisation.virtualbox.guest.x11 = true;
  users.extraGroups.vboxusers.members = [ "sleroq" ];

  nixpkgs.config.packageOverrides = pkgs: {
    steam = pkgs.steam.override {
      withPrimus = true;
      withJava = true;
      extraPkgs = pkgs: with pkgs; [
        libgdiplus
	      bumblebee
	      glxinfo
      ];
    };
  };
}
