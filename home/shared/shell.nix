{ pkgs, opts, ... }:

let
  aliases = {
    cd = "z";
    sudo = "sudo ";
    neofetch = "fastfetch";
  };
in
{
  imports = [
    ../modules/programs/starship.nix
    ../modules/programs/btop.nix
  ];

  programs = {
    bash = {
      enable = true;
      enableCompletion = true;
      shellAliases = aliases;
    };

    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      shellAliases = aliases;
    };

    nushell = {
      enable = true;
      configFile.source = opts.configs + /nushell/config.nu;
      envFile.source = opts.configs + /nushell/env.nu;
      shellAliases = aliases;
    };

    starship = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      enableNushellIntegration = true;
    };

    direnv = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      enableNushellIntegration = true;
    };

    eza = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      enableNushellIntegration = true;
    };
  };

  programs.zoxide = {
    enable = true;
    enableNushellIntegration = true;
    enableZshIntegration = true;
  };

  programs.carapace = {
    enable = true;
    enableNushellIntegration = true;
    enableZshIntegration = true;
  };

  programs.fastfetch.enable = true;

  home.packages = with pkgs; [
    bat
    eza
    fasd
    fd
    fzf
    jq
    ripgrep
    tldr
    onefetch
  ];
}
