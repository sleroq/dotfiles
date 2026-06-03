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
  curlCaBundle = "/etc/ssl/certs/curl-ca-bundle.crt";
  darwin-aliases = {
    nix-switch = "nh darwin switch --hostname portable";
  };
in
{
  imports = [
    ../shared/git.nix
    (import ../shared/shell.nix {
      inherit
        pkgs
        self
        lib
        config
        ;
      enableSshAuthSocket = false;
      extraAliases = darwin-aliases;
      systemVars = {
        CURL_CA_BUNDLE = curlCaBundle;
        SSL_CERT_FILE = curlCaBundle;
        NH_OS_FLAKE = opts.flakeRoot;
      };
    })
  ];

  home = {
    inherit (opts) username;
    homeDirectory = "/Users/${opts.username}"; # TODO: is this needed?
    stateVersion = "25.05";
  };

  # TODO: Move to the system config?
  home.sessionVariables = {
    NH_DARWIN_FLAKE = opts.flakeRoot;
    DOCKER_DEFAULT_PLATFORM = "linux/amd64";
  };

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
        default = true;
      };
    };

    development = {
      enable = true;
      enableBrew = true;
      darwinMagicShit = true;
    };

    programs = {
      pi.enable = true;
      opencode = {
        enable = true;
        useBun = true;
      };
      # mpv.enable = true; # waiting for fix
      ghostty.enable = true;
      extraPackages = with pkgs; [
        nerd-fonts.jetbrains-mono
        inputs'.agenix.packages.default
        ffmpeg
        wget
        dust
        ollama
        amp-cli
        scrcpy
        typst
        inputs'.zig.packages.master
        inputs'.zls.packages.default
      ];
    };
  };
}
