{ pkgs, opts, ... }:

let
  aliases = {
    cd = "z";
    hu = "nix run home-manager/release-24.11 -- switch --flake ${opts.realDotfiles}/home#sleroq";
    sudo = "sudo ";
  };
in
{
  imports = [
    ./programs/starship.nix
    ./programs/btop.nix
  ];

  programs.btop.catppuccin.enable = true;

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    shellAliases = aliases;
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
    enableZshIntegration = true;
  };

  programs.thefuck = {
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
