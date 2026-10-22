{ pkgs, inputs }:
let
  paseo =
    (pkgs.callPackage "${inputs.nixpkgs-master}/pkgs/by-name/pa/paseo/package.nix" {
      nodejs_22 = pkgs.nodejs_24;
    }).overrideAttrs
      (
        finalAttrs: _oldAttrs: {
          version = "0.13.0-beta.1";
          src = pkgs.fetchFromGitHub {
            owner = "getpaseo";
            repo = "paseo";
            tag = "v${finalAttrs.version}";
            hash = "sha256-Z/Banm3O1Bxtk9ShA3uJrftRvX5bvTex9Ng2IWvAAE0=";
          };
          npmDeps = pkgs.fetchNpmDeps {
            inherit (finalAttrs) src;
            name = "paseo-${finalAttrs.version}-npm-deps";
            hash = "sha256-La6xekVRQ9F6UulA6OHX5SzaXv6L0qZ2KpGkRScFd8Q=";
          };

          # Build with upstream's npm 10; npm 11 re-resolves locked React peers offline.
          # The installed wrappers and node-pty headers still use Node 24.
          prePatch = ''
            export PATH="${pkgs.nodejs_22}/bin:$PATH"
          '';
          postInstall = ''
            patchShebangs --build "$out/lib/paseo"
          '';
        }
      );
  desktop =
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.paseo-desktop.overrideAttrs
      (oldAttrs: {
        inherit (paseo)
          version
          src
          npmDeps
          prePatch
          ;
        env = oldAttrs.env // {
          NIX_NPM_FETCHER_VERSION = 1;
        };
        installPhase =
          builtins.replaceStrings
            [ "node scripts/trace-daemon.mjs" ]
            [
              "PASEO_TRACE_DESKTOP=1 node scripts/trace-daemon.mjs"
            ]
            oldAttrs.installPhase;
        postInstall = ''
          patchShebangs --build "$out/share/paseo-desktop"
        '';
      });
  pi = inputs.pi.packages.${pkgs.stdenv.hostPlatform.system}.default;
  codex = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex;
  opencode = pkgs.writeShellScriptBin "opencode" ''
    exec ${inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode2}/bin/opencode2 "$@"
  '';
  piDirenv = pkgs.writeShellScriptBin "pi-direnv" ''
    export PI_FFF_MODE=override
    exec ${pkgs.direnv}/bin/direnv exec "$PWD" ${pi}/bin/pi "$@"
  '';
  tools = [
    paseo
    pi
    piDirenv
    opencode
    codex
    (pkgs.callPackage ../../packages/rift.nix { })
  ]
  ++ (with pkgs; [
    bashInteractive
    git
    gh
    git-crypt
    git-lfs
    curl
    wget
    openssh
    bat
    eza
    fd
    fzf
    jq
    ripgrep
    tmux
    btop
    tree
    unzip
    zip
    zstd
    direnv
    nix-direnv
    nodejs_24
    bun
    pnpm
    yarn
    deno
    typescript
    typescript-language-server
    inputs.zig.packages.${pkgs.stdenv.hostPlatform.system}."0.17.0"
    inputs.zls.packages.${pkgs.stdenv.hostPlatform.system}.default
    go
    gopls
    golangci-lint
    gotools
    (rust-bin.stable.latest.default.override {
      extensions = [ "rust-src" ];
      targets = [ "wasm32-wasip2" ];
    })
    cargo-machete
    python3
    uv
    gcc
    gnumake
    cmake
    pkg-config
    nixfmt
    deadnix
    nixf
    nixd
    nil
    ast-grep
    beans
    shellcheck
    shfmt
    marksman
    agent-browser
    chromium
    redis
  ]);
in
{
  inherit
    paseo
    desktop
    piDirenv
    codex
    tools
    ;
}
