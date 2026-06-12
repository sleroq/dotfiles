{ pkgs, ... }:

{
  home = {
    username = "dev";
    homeDirectory = "/home/dev";
    stateVersion = "24.05";

    packages = with pkgs; [
      bashInteractive
      btop
      curl
      direnv
      fd
      git
      jq
      nil
      nix-direnv
      nixfmt
      podman-compose
      ripgrep
      tmux
      tree
      wget
    ];

    sessionVariables = {
      EDITOR = "nvim";
    };
  };

  programs = {
    bash = {
      enable = true;
      shellAliases = {
        ll = "ls -la";
      };
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    git = {
      enable = true;
      settings = {
        init.defaultBranch = "main";
        pull.rebase = true;
      };
    };

    home-manager.enable = true;

    neovim = {
      enable = true;
      defaultEditor = true;
    };

    ssh = {
      enable = true;
      enableDefaultConfig = false;
    };

    tmux = {
      enable = true;
      clock24 = true;
    };
  };

  xdg.enable = true;
}
