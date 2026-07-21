{ pkgs, opts, lib, inputs', ... }:

{
  programs.neovim = {
    enable = true;
    package = inputs'.neovim-nightly-overlay.packages.default;
    withRuby = false;
    withPython3 = false;
    sideloadInitLua = true;
  };

  home.activation.neovim = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -L "$HOME/.config/nvim/init.lua" ]; then
      case "$(readlink "$HOME/.config/nvim/init.lua")" in
        /nix/store/*-home-manager-files/.config/nvim/init.lua)
          $DRY_RUN_CMD rm $VERBOSE_ARG "$HOME/.config/nvim/init.lua"
          ;;
      esac
    fi

    if [ -d "$HOME/.config/nvim" ] && [ ! -L "$HOME/.config/nvim" ]; then
      $DRY_RUN_CMD rmdir $VERBOSE_ARG "$HOME/.config/nvim"
    fi

    $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
        ${opts.realConfigs}/nvim "$HOME/.config/nvim"
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
    sqlite
    lua
  ];
}
