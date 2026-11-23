{
  lib,
  config,
  opts,
  ...
}:

{
  options.myHome.programs.himalaya.enable = lib.mkEnableOption "Himalaya configuration";

  config = lib.mkIf config.myHome.programs.himalaya.enable {
    programs.himalaya.enable = true;
    accounts.email.accounts.cumserver = rec {
      address = "${opts.username}@cum.army";
      userName = address;
      realName = opts.username;
      primary = true;
      himalaya.enable = true;
      imap = {
        host = "mail.cum.army";
        port = 993;
        authentication = "plain";
        tls.enable = true;
      };
      passwordCommand = [
        "/usr/bin/security"
        "find-generic-password"
        "-s"
        "himalaya-imap"
        "-a"
        address
        "-w"
      ];
    };
  };
}
