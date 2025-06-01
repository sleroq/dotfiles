{ pkgs, opts, lib, ... }:

{
  programs.neovim.enable = true;

  home.activation.neovim = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
        ${opts.realConfigs}/nvim $HOME/.config
  '';

  home.packages = with pkgs; [
    ripgrep
    fd
    lazygit

    htmx-lsp
    vscode-langservers-extracted

    nodejs
    cargo
    shellcheck
    stylua
    tree-sitter
    luajitPackages.luarocks
    luajitPackages.jsregexp
    tailwindcss-language-server
    wakatime
    sqlite
  ];
}
