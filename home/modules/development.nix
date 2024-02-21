{ pkgs, lib, opts, ... }:

with lib;
{
  imports = [
    ./programs/gitui.nix
  ];

  programs.zsh = mkIf opts.zsh-integration {
    envExtra = ''
      # Node.js
      path+=("$HOME/develop/node.js/bin")
      export N_PREFIX="$HOME/develop/node.js"

      # Deno
      path+=("$HOME/.deno/bin")

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
    git-lfs
    git-fame
    nodejs
    yarn
    deno
    nodePackages_latest.typescript
    nodePackages_latest.typescript-language-server
    gopls
    niv
    rnix-lsp
    cargo
    rustc
    godot_4
    marksman
    nil
    lua-language-server

    mongodb-compass
    # pgadmin4
    # postgresql_15
    # radicle-cli

    # TODO: Remove if nothing breaks
    exiftool
    gcc
    gnumake
  ];
}
