{ pkgs, self, inputs', config, lib, ... }:

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
    path = "${config.home.homeDirectory}/.ssh/config";
  };

  # Fix for https://github.com/ryantm/agenix/issues/308
  launchd.agents."activate-agenix".config.KeepAlive =
    lib.mkForce { SuccessfulExit = false; };

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
      ghostty.enable = true;
      extraPackages = [
        inputs'.agenix.packages.default
      ];
    };
  };
}
