{ config, pkgs, opts, lib, ... }:

with config;
{
  programs.neovim = {
    enable = true;
  };

  home.activation.neovim = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
        ${opts.realConfigs}/nvim $HOME/.config
  '';

  # xdg.configFile.nvim = {
  #   enable = true;
  #   source = opts.configs + /nvim;
  # };

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
