{ pkgs, opts, lib, inputs, ... }:

with lib;
let repoUrl = "https://github.com/doomemacs/doomemacs";
in
{
    nixpkgs.overlays = [ inputs.emacs-overlay.overlay ];

    fonts.fontconfig.enable = true;
    home.packages = with pkgs; [
      ## Emacs itself
      binutils # native-comp needs 'as', provided by this
      # 28.2 + native-comp
      # ((emacsPackagesFor emacs-unstable).emacsWithPackages
      ((emacsPackagesFor emacs).emacsWithPackages
        (epkgs: [ epkgs.vterm ]))

      ## Doom dependencies
      git
      (ripgrep.override { withPCRE2 = true; })
      gnutls # for TLS connectivity

      ## Optional dependencies
      fd # faster projectile indexing
      imagemagick # for image-dired
      # (mkIf (config.programs.gnupg.agent.enable)
      #   pinentry_emacs) # in-emacs gnupg prompts
      zstd # for undo-fu-session/undo-tree compression

      ## Module dependencies
      # :checkers spell
      (hunspellWithDicts (with pkgs.hunspellDicts; [
        en-us
        ru_RU
        en_GB-ize
        en_US-large
      ]))
      # :tools editorconfig
      editorconfig-core-c # per-project style config
      # :tools lookup & :lang org +roam
      sqlite
      # :lang latex & :lang org (latex previews)
      texlive.combined.scheme-medium
      # :lang org & graphs
      graphviz
      # :lang web
      html-tidy
      jsbeautifier
      nodePackages_latest.stylelint
      sass
      # :lang org & export with pandoc
      pandoc
      # :lang go
      gomodifytags
      gotests
      gore
      gotools
      # :lang nix
      nixfmt
      # :lang rust
      rustfmt
      rust-analyzer
      # :lang beancount
      beancount
      fava

      # for org-download-clipboard
      maim

      # Fonts
      emacs-all-the-icons-fonts
      nerd-fonts.jetbrains-mono
    ];

    home.activation.emacs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      PATH=$PATH:${lib.makeBinPath [ pkgs.git ]}.
      if [ ! -d "$HOME/.config/emacs" ]; then
          ${pkgs.git}/bin/git clone --depth=1 --single-branch "${repoUrl}" "$HOME/.config/emacs"
          $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
              "${opts.realConfigs}/doom" "$HOME/.config/doom"
      fi
    '';
}
