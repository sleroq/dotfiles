{ ... }:

{
  imports = [
    ../shared/git.nix
    ../shared/development.nix
    (import ../shared/shell.nix { enableSshAuthSocket = false; })
  ];

  home = {
    username = "sleroq";
    homeDirectory = "/Users/sleroq";
    stateVersion = "25.05";
  };

  age.secrets.ssh-config = {
    file = ../secrets/ssh-config;
    path = ".ssh/config";
  };

  myHome = {
    editors = {
      # vscode.enable = true;
      neovim = {
        enable = true;
        enableNeovide = true;
        default = true;
      };
    };
  };
}
