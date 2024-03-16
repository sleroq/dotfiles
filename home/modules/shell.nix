{ config, pkgs, opts, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      cd = "z";
      ls = "eza";
      up = "sudo nix-channel --update && sudo nixos-rebuild switch --upgrade";
      hu = "home-manager switch --flake ${opts.realDotfiles}/home#sleroq";
      sudo = "sudo ";

      l = "ls -lh";
      la = "ls -lAh";
      ll = "ls -l";
      ldot = "ls -ld .*";
      lS = "ls -1Ssh";
      lsr = "ls -lARh";
      lsn = "ls -1";
    };

    history = {
      size = 100000000;
      save = 100000000;
      path = "${config.xdg.dataHome}/zsh/history";
    };

    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "thefuck"
        "colored-man-pages"
        "common-aliases"
        "lol"
        "tmux"
      ];
      theme = "robbyrussell";
    };

    envExtra = ''
      # local path
      path+=("$HOME/.local/bin")

      # Scripts
      path+=("${opts.dotfiles}/scripts")
    '';

    initExtra = ''
      # Fix plugin aliases
      unalias tldr
    '';

    plugins = with pkgs; [
      {
        name = "you-should-use";
        file = "share/zsh/plugins/you-should-use/you-should-use.plugin.zsh";
        src = pkgs.zsh-you-should-use;
      }
    ];
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  home.packages = with pkgs; [
    zsh
    thefuck
    zoxide
    oh-my-zsh
    bat
    eza
    fasd
    fd
    fzf
    jq
    ripgrep
    tldr
    onefetch
    btop
    zsh-completions
  ];
}
