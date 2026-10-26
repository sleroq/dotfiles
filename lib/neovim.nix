{ pkgs, inputs }:
let
  pkgsMaster = import inputs.nixpkgs-master {
    system = pkgs.stdenv.hostPlatform.system;
  };
  package =
    pkgs.wrapNeovimUnstable
      inputs.neovim-nightly-overlay.packages.${pkgs.stdenv.hostPlatform.system}.default
      {
        wrapRc = false;
        withRuby = false;
        withPython3 = false;
        wrapperArgs = [
          "--set"
          "FFF_NVIM"
          "${pkgsMaster.vimPlugins.fff-nvim}"
          "--prefix"
          "PATH"
          ":"
          "${pkgs.lib.makeBinPath [
            pkgs.imagemagick
            pkgs.mermaid-cli
          ]}"
        ];
      };
in
{
  packages = [
    package
  ]
  ++ (with pkgs; [
    ripgrep
    fd
    lazygit
    imagemagick # image.nvim's magick_cli processor
    mermaid-cli # diagram.nvim's Mermaid renderer (mmdc)

    htmx-lsp
    svelte-language-server
    vscode-langservers-extracted

    nodejs
    shellcheck
    stylua
    tree-sitter
    luajitPackages.luarocks
    luajitPackages.jsregexp
    tailwindcss-language-server
    sqlite
    lua
    lua-language-server
  ]);
}
