{ config, pkgs, lib, opts, inputs, ... }:

with lib;
{
  nixpkgs.overlays = [ inputs.emacs-overlay.overlay ];
  services.emacs = {
    enable = true;
    package = pkgs.emacsUnstable;
  };

  home.activation.emacs = hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
        ${opts.realConfigs}/.doom.d $HOME
  '';

  programs.zsh = mkIf opts.zsh-integration {
    envExtra = ''
      # Emacs
      path+=("$HOME/.emacs.d/bin")
    '';
  };

  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
    ## Emacs itself
    binutils # native-comp needs 'as', provided by this
    # 28.2 + native-comp
    ((emacsPackagesFor emacsUnstable).emacsWithPackages (epkgs: [
      epkgs.vterm
    ]))

    ## Doom dependencies
    git
    (ripgrep.override { withPCRE2 = true; })
    gnutls # for TLS connectivity

    ## Optional dependencies
    fd # faster projectile indexing
    imagemagick # for image-dired
    zstd # for undo-fu-session/undo-tree compression

    ## Module dependencies
    # :checkers spell
    (aspellWithDicts (ds: with ds; [ en en-computers en-science ]))
    # :tools editorconfig
    editorconfig-core-c # per-project style config
    # :tools lookup & :lang org +roam
    sqlite
    # :lang latex & :lang org (latex previews)
    texlive.combined.scheme-medium
    # :lang beancount
    beancount
    # fava # HACK Momentarily broken on nixos-unstable

    shellcheck

    # Nix
    nixfmt

    emacs-all-the-icons-fonts
    (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
  ];
}

