{ pkgs, ... }:

{
  imports = [
    ./programs/gitui.nix
    ./programs/zellij.nix
  ];

  programs.nushell = {
    extraEnv = ''
      # Deno
      $env.PATH = ($env.PATH | append ($env.HOME | path join '.deno/bin'))

      # Golang
      $env.GOPATH = ($env.HOME | path join 'develop/go')
      $env.GOBIN = ($env.GOPATH | path join 'bin')
      $env.PATH = ($env.PATH | append $env.GOBIN)
    '';
  };

  programs.zsh = {
    envExtra = ''
      # Deno
      path+=("$HOME/.deno/bin")

      # Golang
      export GOPATH="$HOME/develop/go"
      path+=(go env GOBIN)
    '';
  };

  home.packages = with pkgs; [
    git-lfs
    git-fame
    nodejs
    yarn
    deno
    go
    nodePackages_latest.typescript
    nodePackages_latest.typescript-language-server
    gopls
    niv
    nixd
    cargo
    rustc
    godot_4
    marksman
    nil
    lua-language-server

    # python39
    # python39Packages.pip

    # mongodb-compass
    # pgadmin4
    # postgresql_15
    # radicle-cli

    exiftool
    gcc
    gnumake
  ];
}
