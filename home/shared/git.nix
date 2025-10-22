_:

{
  programs.git = {
    enable = true;
    settings = {
      user.name = "Sleroq";
      user.email = "hireme@sleroq.link";
      push.autoSetupRemote = "true";
      init.defaultBranch = "master";
    };
  };
}
