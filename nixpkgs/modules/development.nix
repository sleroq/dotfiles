{ config, pkgs, lib, opts, ... }:

with lib;
{
  programs.zsh = mkIf opts.zsh-integration {
    envExtra = ''
      # Node.js
      path+=("$HOME/develop/node.js/bin")
      export N_PREFIX="$HOME/develop/node.js"

      # Golang
      export GOPATH=$HOME/develop/go
      path+=("$(go env GOPATH)/bin")
    '';
  };

  home.packages = with pkgs; [
    vscode-fhs
    docker
    go
    nodejs
    gcc
    gnumake
    zig
  ];
}
