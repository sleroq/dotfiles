{ pkgs, opts, ... }:

let
  aliases = {
    # cd = "z";
    up = "sudo nix-channel --update and sudo nixos-rebuild switch --upgrade"; # TODO: Make shell-agnostic
    hu = "nix run home-manager/release-24.11 -- switch --flake ${opts.realDotfiles}/home#sleroq";
    sudo = "sudo ";
  };
in
{
  imports = [
    ./programs/starship.nix
  ];

  programs.nushell = {
    enable = true;
    configFile.source = opts.configs + /nushell/config.nu;
    envFile.source = opts.configs + /nushell/env.nu;
    shellAliases = aliases;
  };

  # FIXME: Waiting for fix
  # programs.zoxide = {
  #   enable = true;
  #   enableNushellIntegration = true;
  # };

  programs.thefuck = {
    enable = true;
    enableNushellIntegration = true;
  };

  programs.carapace = {
    enable = true;
    enableNushellIntegration = true;
  };

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
    fastfetch
    btop
  ];
}
