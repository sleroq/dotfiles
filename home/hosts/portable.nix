{
  pkgs,
  self,
  inputs',
  config,
  lib,
  opts,
  ...
}:

let
  darwin-aliases = {
    nix-switch = "nh darwin switch --hostname $HOST";
  };
in
{
  imports = [
    ../shared/git.nix
    (import ../shared/shell.nix {
      inherit pkgs self;
      enableSshAuthSocket = false;
      extraAliases = darwin-aliases;
    })
  ];

  home = {
    inherit (opts) username;
    homeDirectory = "/Users/${opts.username}"; # TODO: is this needed?
    stateVersion = "25.05";

    # Adding opencode installed separately to the path
    sessionPath = [ "${config.home.homeDirectory}/.opencode/bin" ];
  };

  # TODO: Move to the system config?
  home.sessionVariables.NH_DARWIN_FLAKE = opts.flakeRoot;

  age.secrets.ssh-config = {
    file = ../secrets/ssh-config;
    path = "${config.home.homeDirectory}/.ssh/config";
  };

  # Fix for https://github.com/ryantm/agenix/issues/308
  launchd.agents."activate-agenix".config.KeepAlive = lib.mkForce { SuccessfulExit = false; };

  myHome = {
    editors = {
      # vscode.enable = true;
      zed = {
        enable = true;
        package = null;
      };
      neovim = {
        enable = true;
        enableNeovide = true;
        default = true;
      };
    };

    development = {
      enable = true;
      enableBrew = true;
      darwinMagicShit = true;
    };

    programs = {
      ghostty.enable = true;
      extraPackages = with pkgs; [
        inputs'.agenix.packages.default
        mpv
        ffmpeg
        wget
        dust
        ollama
      ];
    };
  };
}
