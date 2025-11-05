{ pkgs, self, inputs', config, ... }:

{
  imports = [
    ../shared/git.nix
    ../shared/development.nix
    (import ../shared/shell.nix { inherit pkgs self; enableSshAuthSocket = false; })
  ];

  home = {
    username = "sleroq";
    homeDirectory = "/Users/sleroq";
    stateVersion = "25.05";
  };

  age = {
    identityPaths = [ (config.home.homeDirectory + "/.ssh/id_ed25519") ];
  };

  age.secrets.ssh-config = {
    file = ../secrets/ssh-config;
    path = config.home.homeDirectory + "/.ssh/config";
  };

  age.secrets.test = {
    file = ../secrets/ssh-config;
    path = "/Users/sleroq/test";
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

    programs = {
      extraPackages = [
        inputs'.agenix.packages.default
      ];
    };
  };
}
