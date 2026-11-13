{
  pkgs,
  lib,
  config,
  enableSshAuthSocket ? true,
  extraAliases ? { },
  ...
}:

let
  aliases = {
    sudo = "sudo ";
    neofetch = "fastfetch";
    vim = "nvim";
    vi = "nvim";
  }
  // extraAliases;
  vars =
    if enableSshAuthSocket then
      {
        SSH_AUTH_SOCK = "/run/user/1000/ssh-agent";
      }
    else
      { };
in
{
  imports = [
    ../modules/programs/starship.nix
    ../modules/programs/btop.nix
  ];
  home = {
    # Do not rely on the PATH inherited from macOS applications or terminal
    # launchers: they can put /usr/bin before the Home Manager profile.
    sessionPath = [ "${config.home.profileDirectory}/bin" ];
    sessionVariables =
      if enableSshAuthSocket then
        {
          SSH_AUTH_SOCK = "/run/user/1000/ssh-agent";
        }
      else
        { };
  };

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
        aliases
        vars
        ;
    };

    starship = {
      enable = true;
    };

    direnv = {
      enable = true;
      silent = true;
      config.global.hide_env_diff = true;
      nix-direnv.enable = true;
    };

    yazi = {
      enable = true;
      shellWrapperName = "y";
    };

    zoxide = {
      enable = true;
      options = [
        "--cmd"
        "cd"
      ];
    };

    carapace = {
      enable = true;
    };

    fastfetch.enable = true;
  };

  home.packages = with pkgs; [
    bat
    eza
    fd
    fzf
    jq
    ripgrep
    outfieldr
    onefetch
  ];
}
