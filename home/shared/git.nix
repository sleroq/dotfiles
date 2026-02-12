{ config, pkgs, ... }:

{
  age.secrets.gitconfig-wrk = {
    file = ../secrets/gitconfig-wrk;
    path = "${config.home.homeDirectory}/.config/git/includes/gitconfig-wrk";
  };
  age.secrets.gitconfig-wrk-global = {
    file = ../secrets/gitconfig-wrk-global;
    path = "${config.home.homeDirectory}/.config/git/includes/gitconfig-wrk-global";
  };
  age.secrets.gitignore-wrk = {
    file = ../secrets/gitignore-wrk;
    path = "${config.home.homeDirectory}/.config/git/includes/gitignore-wrk";
  };
  age.secrets.allowed-signers-wrk = {
    file = ../secrets/allowed-signers-wrk;
    path = "${config.home.homeDirectory}/.ssh/allowed-signers-wrk";
  };
  age.secrets.allowed-signers = {
    file = ../secrets/allowed-signers;
    path = "${config.home.homeDirectory}/.ssh/allowed-signers";
  };

  home.file.".config/git/includes/gitignore-anytype".source = ../config/git/gitignore-anytype;
  home.file.".config/git/includes/gitconfig-anytype".source = ../config/git/gitconfig-anytype;

  home.packages = [
    pkgs.gnupg
    pkgs.gh
    pkgs.gitbutler
  ];

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Sleroq";
        email = "hireme@sleroq.link";
        signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK72BBTnP5Os5ZQfS1BuigNzWMqNFl7lgUH4CJq1bl9P cantundo@pm.me";
      };
      push.autoSetupRemote = "true";
      init.defaultBranch = "master";
      rerere.enabled = true;
      commit.gpgSign = true;
      gpg = {
        format = "ssh";
        ssh.allowedSignersFile = "~/.ssh/allowed-signers";
      };
    };
    ignores = [
      ".gitlab.nvim"
      ".aider*"
    ];
    includes = [
      {
        condition = "gitdir:~/Job/**";
        path = "~/.config/git/includes/gitconfig-wrk";
      }
      {
        path = "~/.config/git/includes/gitconfig-wrk-global";
      }
      {
        condition = "gitdir:~/develop/frg/**";
        path = "~/.config/git/includes/gitconfig-wrk";
      }
      {
        condition = "gitdir:~/develop/temp/anyproto/**";
        path = "~/.config/git/includes/gitconfig-anytype";
      }
    ];
  };
}
