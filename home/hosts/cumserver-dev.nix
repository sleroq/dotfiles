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
      fd
      git
      jq
      nil
      nixfmt
      podman-compose
      ripgrep
      tmux
      tree
      wget
      helix
    ];

    sessionVariables = {
      EDITOR = "hx";
      COLORTERM = "truecolor";
      TERM = "xterm-256color";
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
        user = {
          name = "santakameow";
          email = "sakanai@cum.army";
        };
        init.defaultBranch = "main";
        pull.rebase = true;
      };
    };

    home-manager.enable = true;

    neovim = {
      enable = true;
      # defaultEditor = true;
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
