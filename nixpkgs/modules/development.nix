{ config, pkgs, lib, opts, ... }:

with lib;
{
  programs.zsh = mkIf opts.zsh-integration {
    envExtra = ''
      # Node.js
      path+=("$HOME/develop/node.js/bin")
      export N_PREFIX="$HOME/develop/node.js"

      # Golang
      path+=("$(go env GOPATH)/bin")
    '';
  };

  programs.go = {
    enable = true;
    goPath = "develop/go";
    goBin = "develop/go/bin";
  };

  home.packages = with pkgs; [
    vscode-fhs
    nodejs
    gcc
    gnumake
    zig
  ];
}
