_:

{
  homebrew = {
    enable = true;
    casks = [ "rcmd" ];
  };

  launchd.user.agents.rcmd.serviceConfig = {
    ProgramArguments = [
      "/usr/bin/open"
      "-a"
      "/Applications/rcmd.app"
    ];
    RunAtLoad = true;
  };
}
