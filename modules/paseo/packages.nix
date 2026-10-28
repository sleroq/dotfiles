{ pkgs, inputs' }:
let
  paseo = inputs'.llm-agents-paseo.packages.paseo;
  desktop = inputs'.llm-agents.packages.paseo-desktop;
  pi = inputs'.pi.packages.default;
  codex = inputs'.llm-agents.packages.codex;
  opencode = pkgs.writeShellScriptBin "opencode" ''
    exec ${inputs'.llm-agents.packages.opencode2}/bin/opencode2 "$@"
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
    inputs'.zig.packages."0.17.0"
    inputs'.zls.packages.default
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
