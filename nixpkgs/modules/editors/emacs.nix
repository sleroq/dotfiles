{ config, pkgs, lib, opts, emacs-overlay, ... }:

with lib;
{
  nixpkgs.overlays = [ emacs-overlay.overlay ];
  services.emacs = {
    enable = true;
    package = pkgs.emacsUnstable;
  };

  home.file.".doom.d" = {
    enable = true;
    source = opts.configs + /.doom.d;
  };

  home.sessionPath = [
    "${config.xdg.configHome}/.emacs.d/bin"
  ];

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
    # ((emacsPackagesFor emacsUnstable).emacsWithPackages
    #   (epkgs: [ epkgs.vterm ]))
    ((emacsPackagesFor emacs).emacsWithPackages (epkgs: [
      epkgs.vterm
    ]))
    libvterm
    libtool

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

