{ pkgs, self, enableSshAuthSocket ? true, ... }:

let
  aliases = {
    cd = "z";
    sudo = "sudo ";
    neofetch = "fastfetch";
    vim = "nvim";
    vi = "nvim";
  };
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

    nushell = {
      enable = true;
      configFile.source = self + /home/config/nushell/config.nu;
      envFile.source = self + /home/config/nushell/env.nu;
      shellAliases = aliases;
      environmentVariables = vars;
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
      enableBashIntegration = true;
      enableZshIntegration = true;
      enableNushellIntegration = true;
    };

    zoxide = {
      enable = true;
      enableNushellIntegration = true;
      enableZshIntegration = true;
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
