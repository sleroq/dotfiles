{ pkgs, ... }:
{
  imports = [
    ../modules/programs/gitui.nix
    ../modules/programs/zellij.nix
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
    initContent = ''
      # Deno
      export PATH="$PATH:$HOME/.deno/bin"

      # Golang
      export GOPATH="$HOME/develop/go"
      export GOBIN="$GOPATH/bin"
      export PATH="$PATH:$GOBIN"
    '';
  };

  programs.bash = {
    initExtra = ''
      # Deno
      export PATH="$PATH:$HOME/.deno/bin"

      # Golang
      export GOPATH="$HOME/develop/go"
      export GOBIN="$GOPATH/bin"
      export PATH="$PATH:$GOBIN"
    '';
  };

  # TODO: Seems bloated, too much dev tools?
  # Do I really need nix/lua lsp
  home.packages = with pkgs; [
    git-lfs
    # git-fame
    nodejs
    yarn
    deno
    go
    golangci-lint
    nodePackages_latest.typescript
    nodePackages_latest.typescript-language-server
    gopls
    cargo
    # rustc
    # godot_4
    marksman

    nixd # Nix language server
    nil # Another nix language server? (zed needs it)
    package-version-server # JSON language server
    lua-language-server

    # python39
    # python39Packages.pip

    # mongodb-compass
    # pgadmin4
    # postgresql_15
    # radicle-cli

    # exiftool
    gcc # For go build
    gnumake # Generally usefull sometimes
  ];
}
