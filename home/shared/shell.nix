{
  pkgs,
  lib,
  config,
  enableSshAuthSocket ? true,
  extraAliases ? { },
  ...
}@args:

let
  aliases = {
    sudo = "sudo ";
    neofetch = "fastfetch";
    vim = "nvim";
    vi = "nvim";
  } // extraAliases;
  vars = if enableSshAuthSocket then {
    SSH_AUTH_SOCK = "/run/user/1000/ssh-agent";
  } else {};
in
{
  imports = [
    ../modules/programs/starship.nix
    ../modules/programs/btop.nix
  ];
  home.sessionVariables = if enableSshAuthSocket then {
    SSH_AUTH_SOCK = "/run/user/1000/ssh-agent";
  } else {};

  programs = {
    bash = {
      enable = true;
      enableCompletion = true;
      shellAliases = aliases;
      sessionVariables = vars;
    };

    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      shellAliases = aliases;
      sessionVariables = vars;
    };

    nushell = import ./shell-nushell.nix {
      inherit
        lib
        config
        args
        aliases
        vars
        ;
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
      enable = false;
      enableBashIntegration = true;
      enableZshIntegration = true;
      enableNushellIntegration = true;
    };

    yazi = {
      enable = true;
      shellWrapperName = "y";
      enableBashIntegration = true;
      enableZshIntegration = true;
      enableNushellIntegration = true;
    };

    zoxide = {
      enable = true;
      enableBashIntegration = true;
      enableNushellIntegration = true;
      enableZshIntegration = true;
      options = [ "--cmd" "cd" ];
    };

    carapace = {
      enable = true;
      enableNushellIntegration = true;
      enableZshIntegration = true;
    };

    fastfetch.enable = true;
  };

  home.packages = with pkgs; [
    bat
    eza
    fasd
    fd
    fzf
    jq
    ripgrep
    outfieldr
    onefetch
  ];
}
