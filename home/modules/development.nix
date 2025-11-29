{ pkgs, opts, config, lib, ... }:
with lib;
let
  cfg = config.myHome.development;
  brewEnabled = cfg.enableBrew;
  darwinMagicShit = cfg.darwinMagicShit;
in
{
  options.myHome.development = {
    enable = mkEnableOption "Development tools and shell configurations";
    enableBrew = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Homebrew integration in shell environments";
    };
    darwinMagicShit = mkOption {
      type = types.bool;
      default = false;
      description = "Force xcode stuff instead of nix";
    };
  };

  # TODO: Make conditional
  imports = [
    # ../modules/programs/gitui.nix
    # ../modules/programs/zellij.nix
  ];

  config = mkIf cfg.enable {

    programs.nushell = {
      extraEnv = ''
        $env.PATH = ($env.PATH | append ($env.HOME | path join '.local/bin'))

        # Deno
        $env.PATH = ($env.PATH | append ($env.HOME | path join '.deno/bin'))

        # Bun
        $env.PATH = ($env.PATH | append ($env.HOME | path join '.cache/.bun/bin'))

        # Golang
        $env.GOPATH = ($env.HOME | path join 'develop/go')
        $env.GOBIN = ($env.GOPATH | path join 'bin')
        $env.PATH = ($env.PATH | append $env.GOBIN)

        $env.NH_FLAKE = "${opts.flakeRoot}";

        ${if brewEnabled then ''$env.PATH = ($env.PATH | split row (char esep) | prepend '/opt/homebrew/bin')'' else ""}

        ${if darwinMagicShit then ''
          $env.CARGO_TARGET_AARCH64_APPLE_DARWIN_LINKER = (xcrun --find clang | str trim)
          $env.CC = (xcrun --find clang | str trim)
          $env.CXX = (xcrun --find clang++ | str trim)
          $env.SDKROOT = (xcrun --show-sdk-path | str trim)
        '' else ""}
      '';
    };

    programs.zsh = {
      initContent = ''
        export PATH="$PATH:$HOME/.local/bin"

        # Deno
        export PATH="$PATH:$HOME/.deno/bin"

        # Bun
        export PATH="$PATH:$HOME/.cache/.bun/bin"

        # Golang
        export GOPATH="$HOME/develop/go"
        export GOBIN="$GOPATH/bin"
        export PATH="$PATH:$GOBIN"

        export NH_FLAKE="${opts.flakeRoot}";

        ${if brewEnabled then ''eval "$(/opt/homebrew/bin/brew shellenv)"'' else ""}

        ${if darwinMagicShit then ''
          export CARGO_TARGET_AARCH64_APPLE_DARWIN_LINKER=$(xcrun --find clang)
          export CC=$(xcrun --find clang)
          export CXX=$(xcrun --find clang++)
          export SDKROOT=$(xcrun --show-sdk-path)
        '' else ""}
      '';
    };

    programs.bash = {
      initExtra = ''
        export PATH="$PATH:$HOME/.local/bin"

        # Deno
        export PATH="$PATH:$HOME/.deno/bin"

        # Bun
        export PATH="$PATH:$HOME/.cache/.bun/bin"

        # Golang
        export GOPATH="$HOME/develop/go"
        export GOBIN="$GOPATH/bin"
        export PATH="$PATH:$GOBIN"

        export NH_FLAKE="${opts.flakeRoot}";

        ${if brewEnabled then ''eval "$(/opt/homebrew/bin/brew shellenv)"'' else ""}

        ${if darwinMagicShit then ''
          export CARGO_TARGET_AARCH64_APPLE_DARWIN_LINKER=$(xcrun --find clang)
          export CC=$(xcrun --find clang)
          export CXX=$(xcrun --find clang++)
          export SDKROOT=$(xcrun --show-sdk-path)
        '' else ""}
      '';
    };

    # TODO: optional opencode configuration?

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
      rustc
      # godot_4
      marksman
      hadolint

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
      bun
      pnpm
      sshfs
    ];
  };
}
