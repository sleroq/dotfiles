{ config, ... }:
{
  imports = [ ../modules/sing-box.nix ];

  age.secrets.sing-box-subscription-main = {
    file = ./secrets/sing-box-subscription-main;
    mode = "0600";
  };

  age.secrets.sing-box-subscription-cw = {
    file = ./secrets/sing-box-subscription-cw;
    mode = "0600";
  };

  sleroq.sing-box = {
    enable = true;
    subscription = {
      enable = true;
      sources = [
        {
          name = "main";
          urlFile = config.age.secrets.sing-box-subscription-main.path;
        }
        {
          name = "cw";
          urlFile = config.age.secrets.sing-box-subscription-cw.path;
        }
      ];
    };
    directDomains = [
      "рф"
      "ru"
      "local"
      "nelocal"
      "frg"
      "frankrg.com"
      "steampowered.com"
      "steamcommunity.com"
      "steamstatic.com"
      "steamcontent.com"
      "steamserver.net"
      "steamusercontent.com"
      "steam-chat.com"
      "valvesoftware.com"
      "energotransbank.com"
    ];
    directProcessNames = [
      "steam"
      "steamwebhelper"
    ];
    logLevel = "warn";
  };
}
