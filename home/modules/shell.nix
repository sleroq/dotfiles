{ pkgs, config, opts, ... }:

let
  aliases = {
    cd = "z";
    up = "sudo nix-channel --update and sudo nixos-rebuild switch --upgrade"; # TODO: Make shell-agnostic
    hu = "home-manager switch --flake ${opts.realDotfiles}/home#sleroq";
    sudo = "sudo ";
    # FIXME: Redo as binary or .desktop file
    discord = "flatpak run dev.vencord.Vesktop --ozone-platform=wayland --disable-features=UseChromeOSDirectVideoDecoder --disable-gpu-memory-buffer-compositor-resources --disable-gpu-memory-buffer-video-frames --enable-hardware-overlays";
  };
in
{
  imports = [
    ./programs/starship.nix
  ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = aliases;
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

      export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib}/lib";
    '';

    initExtra = ''
      # Fix plugin aliases
      unalias tldr
    '';

    plugins = [
      {
        name = "you-should-use";
        file = "share/zsh/plugins/you-should-use/you-should-use.plugin.zsh";
        src = pkgs.zsh-you-should-use;
      }
    ];
  };

  programs.nushell = {
    enable = true;
    configFile.source = opts.configs + /nushell/config.nu;
    envFile.source = opts.configs + /nushell/env.nu;
    shellAliases = aliases;
  };

  programs.zoxide = {
    enable = true;
    enableNushellIntegration = true;
  };

  programs.thefuck = {
    enable = true;
    enableNushellIntegration = true;
  };

  programs.carapace = {
    enable = true;
    enableNushellIntegration = true;
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
