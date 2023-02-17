{ config, pkgs, opts, ... }:

{
  programs.zsh = {
    enable = true;

    shellAliases = {
      cd = "z";
      update = "sudo nixos-rebuild switch --upgrade";
      hmdate = "home-manager switch";
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

      # Wayland
      if [[ -z $DESKTOP_SESSION || $XDG_SESSION_TYPE != 'x11' ]]
      then
        export MOZ_ENABLE_WAYLAND=1
        export QT_QPA_PLATFORM=wayland-egl
        export ELM_DISPLAY=wl
        export SDL_VIDEODRIVER=wayland
        export _JAVA_AWT_WM_NONREPARENTING=1
        export XDG_CURRENT_DESKTOP=sway
        export XDG_SESSION_DESKTOP=sway
      fi
    '';
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  home.packages = with pkgs; [
    zsh
    nix-zsh-completions
    zoxide
    oh-my-zsh
    bat
    exa
    fasd
    fd
    fzf
    jq
    ripgrep
    tldr
  ];
}
