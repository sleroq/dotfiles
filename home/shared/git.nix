_:

{
  programs.git = {
    enable = true;
    userName = "Sleroq";
    userEmail = "hireme@sleroq.link";
    extraConfig = {
      "push" = {
        "autoSetupRemote" = "true";
      };
    };
  };
}
