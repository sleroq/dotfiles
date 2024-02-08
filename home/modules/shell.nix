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

      # Download Znap, if it's not there yet.
      [[ -r "$HOME/develop/other/znap/znap.zsh" ]] ||
        git clone --depth 1 -- \
          https://github.com/marlonrichert/zsh-snap.git "$HOME/develop/other/znap"

      source "$HOME/develop/other/znap/znap.zsh"

      znap source marlonrichert/zsh-autocomplete
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
