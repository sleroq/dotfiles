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
    home.sessionPath = [
      "${config.home.homeDirectory}/.local/bin"
      "${config.home.homeDirectory}/.deno/bin"
      "${config.home.homeDirectory}/.bun/bin"
      "${config.home.homeDirectory}/develop/go/bin"
    ] ++ lib.optional brewEnabled "/opt/homebrew/bin";

    home.sessionVariables = {
      GOPATH = "${config.home.homeDirectory}/develop/go";
      GOBIN = "${config.home.homeDirectory}/develop/go/bin";
      NH_FLAKE = opts.flakeRoot;
    };

    programs.nushell = {
      extraEnv = ''
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
