{ config, pkgs, opts, lib, inputs, ... }:

with config;
{
  nixpkgs.overlays = [ inputs.neovim-nightly-overlay.overlay ];
  programs.neovim = {
    enable = true;
    package = pkgs.neovim-nightly;
  };

  home.activation.neovim = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
        ${opts.realConfigs}/nvim $HOME/.config
  '';

  home.packages = with pkgs; [
    neovide

    ripgrep
    fd
    lazygit

    nodejs
    cargo
    shellcheck
    stylua
    luajitPackages.luarocks

    emacs-all-the-icons-fonts
  ];
}
