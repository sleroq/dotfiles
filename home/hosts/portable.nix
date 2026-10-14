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
    ../modules/ast-grep.nix
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
    sessionPath = [
      "$HOME/.orbstack/bin"
      "/Applications/Obsidian.app/Contents/MacOS"
    ];
  };

  programs.zsh.profileExtra = ''
    source "$HOME/.orbstack/shell/init.zsh" 2>/dev/null || :
  '';

  # TODO: Move to the system config?
  home.sessionVariables = {
    NH_DARWIN_FLAKE = opts.flakeRoot;
    DOCKER_DEFAULT_PLATFORM = "linux/amd64";
  };

  age = {
    # macOS purges DARWIN_USER_TEMP_DIR, agenix's default, leaving dangling links.
    # Keep both the generation store and its current-generation link in state.
    secretsDir = "${config.xdg.stateHome}/agenix";
    secretsMountPoint = "${config.xdg.stateHome}/agenix.d";
    secrets.ssh-config = {
      file = ../secrets/ssh-config;
      path = "${config.home.homeDirectory}/.ssh/config";
    };
  };

  # Remove agenix#308's Crashed=false default (which restarts successful jobs).
  # PathState on the destination did not detect deletion of its symlink target.
  launchd.agents."activate-agenix".config.KeepAlive = lib.mkForce {
    SuccessfulExit = false;
  };

  myHome = {
    astGrep.enable = true;

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
      hammerspoon.enable = true;
      pi.enable = true;
      paseo.enable = true;
      pi.cloudflare.enable = true;
      opencode.enable = true;
      # mpv.enable = true; # waiting for fix
      ghostty.enable = true;
      extraPackages = with pkgs; [
        nerd-fonts.jetbrains-mono
        inputs'.agenix.packages.default
        # Upstream only exposes Linux flake packages; its derivation also supports Darwin.
        (pkgs.callPackage "${self.inputs.cliamp}/nix/package.nix" {
          version = self.inputs.cliamp.shortRev;
        })
        ffmpeg
        wget
        uv
        dust
        ollama
        moonlight-qt
        scrcpy
        typst
        inputs'.zig.packages.master
        inputs'.zls.packages.default
      ];
    };
  };
}
