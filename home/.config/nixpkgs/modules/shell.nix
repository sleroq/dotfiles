{ config, pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    shellAliases = {
      cd = "z";
      update = "sudo nixos-rebuild switch --upgrade";
      hmdate = "home-manager switch";
    };
    history = {
      size = 100000000;
      save = 100000000;
      path = "${config.xdg.dataHome}/zsh/history";
    };
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "thefuck" ];
      theme = "robbyrussell";
    };
    envExtra = ''
      # local path
      path+=("$HOME/.local/bin")

      # Scripts
      path+=("$HOME/develop/other/dotfiles/scripts")

      # Node.js
      path+=("$HOME/develop/node.js/bin")
      export N_PREFIX="$HOME/develop/node.js"

      # Golang
      export GOPATH=$HOME/develop/go
      path+=("$(go env GOPATH)/bin")

      # Safe place
      export SAFE_PLACE=/tmp/vault
    '';
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };
}