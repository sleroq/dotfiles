{ pkgs, inputs }:
let
  paseo =
    (pkgs.callPackage "${inputs.nixpkgs-master}/pkgs/by-name/pa/paseo/package.nix" {
      nodejs_22 = pkgs.nodejs_24;
    }).overrideAttrs
      {
        # Build with upstream's npm 10; npm 11 re-resolves locked React peers offline.
        # The installed wrappers and node-pty headers still use Node 24.
        prePatch = ''
          export PATH="${pkgs.nodejs_22}/bin:$PATH"
        '';
      };
  pi = inputs.pi.packages.${pkgs.stdenv.hostPlatform.system}.default;
  codex = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex;
  opencode2 = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode2;
  opencodePaseo = pkgs.writeShellScriptBin "opencode-paseo" ''
    export OPENCODE_DB="paseo-opencode2.db"
    export OPENCODE_CONFIG_DIR="$HOME/.config/paseo-opencode2"
    exec ${opencode2}/bin/opencode2 "$@"
  '';
  piDirenv = pkgs.writeShellScriptBin "pi-direnv" ''
    export PI_FFF_MODE=override
    exec ${pkgs.direnv}/bin/direnv exec "$PWD" ${pi}/bin/pi "$@"
  '';
  tools = [
    paseo
    pi
    piDirenv
    opencode2
    opencodePaseo
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
    piDirenv
    opencodePaseo
    codex
    tools
    ;
}
