{ config, pkgs, opts, ... }:

{
  programs.zsh = {
    enable = true;

    shellAliases = {
      cd = "z";
      ls = "eza";
      update = "sudo nixos-rebuild switch --upgrade";
      hmdate = "home-manager switch"; # TODO: fix to work with nix flakes
      sudo = "sudo ";
      tmus = "tmux -f ~/.config/tmux/tmux.conf";
    };

    history = {
      size = 100000000;
      save = 100000000;
      path = "${config.xdg.dataHome}/zsh/history";
    };

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "thefuck" ];
      theme = "robbyrussell";
    };

    envExtra = ''
      # local path
      path+=("$HOME/.local/bin")

      # Scripts
      path+=("${opts.dotfiles}/scripts")
    '';
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  home.packages = with pkgs; [
    zsh
    thefuck
    nix-zsh-completions
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
  ];
}
