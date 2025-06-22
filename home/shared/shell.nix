{ pkgs, opts, ... }:

let
  runHM = command : "nix run home-manager/master -- ${command} --flake ${opts.repoPathString}/home/hosts/${opts.host}#sleroq";

  aliases = {
    cd = "z";
    hu = runHM "switch";
    hn = runHM "news";
    sudo = "sudo ";
    neofetch = "fastfetch";
  };
in
{
  imports = [
    ../modules/programs/starship.nix
    ../modules/programs/btop.nix
  ];

  programs.bash = {
    enable = true;
    shellAliases = aliases;
  };

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
