{ config, pkgs, opts, ... }:

with config;
{
  programs.neovim = {
    enable = true;
  };

  xdg.configFile.nvim = {
    enable = true;
    source = opts.configs + /nvim;
  };

  home.packages = with pkgs; [
    ripgrep
    fd
    lazygit

    nodejs
    cargo
    shellcheck

    emacs-all-the-icons-fonts
  ];
}
