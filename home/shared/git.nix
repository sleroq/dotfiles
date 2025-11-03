_:

{
  age.secrets.gitconfig-work = {
    file = ../secrets/gitconfig-work;
    path = ".gitconfig-work";
  };
  age.secrets.allowed-signers-work = {
    file = ../secrets/allowed-signers-work;
    path = ".ssh/allowed-signers-work";
  };
  age.secrets.allowed-signers = {
    file = ../secrets/allowed-signers;
    path = ".ssh/allowed-signers";
  };

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
      gpg = {
        format = "ssh";
        ssh.allowedSignersFile = ".ssh/allowed-signers";
      };
    };
    ignores = [
      "AGENTS.md"
      ".gitlab.nvim"
    ];
    includes = [
      {
        condition = "gitdir:~/Job/";
        path = "~/.gitconfig-work";
      }
    ];
  };
}
