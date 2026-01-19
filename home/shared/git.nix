{ config, pkgs, ... }:

{
  age.secrets.gitconfig-work = {
    file = ../secrets/gitconfig-work;
    path = "${config.home.homeDirectory}/.gitconfig-work";
  };
  age.secrets.allowed-signers-work = {
    file = ../secrets/allowed-signers-work;
    path = "${config.home.homeDirectory}/.ssh/allowed-signers-work";
  };
  age.secrets.allowed-signers = {
    file = ../secrets/allowed-signers;
    path = "${config.home.homeDirectory}/.ssh/allowed-signers";
  };

  home.packages = [ pkgs.gnupg pkgs.gh ];

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
      "AGENTS.md"
      ".gitlab.nvim"
      ".aider*"
    ];
    includes = [
      {
        condition = "gitdir:~/Job/";
        path = "~/.gitconfig-work";
      }
      {
        condition = "gitdir:~/develop/frg/";
        path = "~/.gitconfig-work";
      }
    ];
  };
}
