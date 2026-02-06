{ config, pkgs, ... }:

{
  age.secrets.gitconfig-wrk = {
    file = ../secrets/gitconfig-wrk;
    path = "${config.home.homeDirectory}/.gitconfig-wrk";
  };
  age.secrets.gitignore-wrk = {
    file = ../secrets/gitignore-wrk;
    path = "${config.home.homeDirectory}/.gitignore-wrk";
  };
  age.secrets.allowed-signers-wrk = {
    file = ../secrets/allowed-signers-wrk;
    path = "${config.home.homeDirectory}/.ssh/allowed-signers-wrk";
  };
  age.secrets.allowed-signers = {
    file = ../secrets/allowed-signers;
    path = "${config.home.homeDirectory}/.ssh/allowed-signers";
  };

  home.packages = [
    pkgs.gnupg
    pkgs.gh
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
        condition = "gitdir:~/Job/";
        path = "~/.gitconfig-wrk";
      }
      {
        condition = "gitdir:~/develop/frg/";
        path = "~/.gitconfig-wrk";
      }
      {
        condition = "gitdir:~/Job/";
        path = "~/.gitignore-wrk";
      }
      {
        condition = "gitdir:~/develop/frg/";
        path = "~/.gitignore-wrk";
      }
    ];
  };
}
