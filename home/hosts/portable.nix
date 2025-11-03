{ ... }:

{
  home = {
    username = "sleroq";
    homeDirectory = "/Users/sleroq";
    stateVersion = "25.05";
  };

  age.secrets.ssh-config = {
    file = ../secrets/ssh-config;
    path = ".ssh/config";
  };
  
  editors = {
    # vscode.enable = true;
    neovim = {
      enable = true;
      enableNeovide = true;
      default = true;
    };
  };

  sleroq = {
    apps.enable = true;
    flatpakIntegration.enable = false; # Linux-specific
    kwallet.enable = false; # Linux-specific
    sound.enable = false; # Linux-specific
    wms.enable = false; # Linux-specific, wayland/x11
    workVpn.enable = false; # Linux-specific openvpn
    tailscale.enable = true; # Cross-platform
    sing-box.enable = false; # Linux-specific
  };
}
