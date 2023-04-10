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
    nodejs
    yarn
    deno
    nodePackages_latest.typescript
    nodePackages_latest.typescript-language-server
    niv
    helix

    mongodb-compass
    pgadmin4
    postgresql_15
    # radicle-cli

    exiftool
    gcc
    gnumake
    zig
  ];
}
