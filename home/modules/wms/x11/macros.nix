{ lib, pkgs, ... }:

with lib;
{
  home.packages = with pkgs; [
    xcape
    xorg.xmodmap
  ];

  systemd.user.services.macros = {
    Unit = {
      Description = "Macro keybindings";
      Documentation = [ "man:xmodmap" "man:xcape" ];
    };

    Service = {
      ExecStart = ''
        xmodmap -e "clear lock"
        xmodmap -e "keysym Caps_Lock = Control_L"
        xmodmap -e "keysym Control_L = Caps_Lock"
        xmodmap -e "add Lock = Caps_Lock"
        xmodmap -e "keycode 38 = Left"
        xmodmap -e "keycode 39 = Down"
        xmodmap -e "keycode 40 = Up"
        xmodmap -e "keycode 41 = Right"
        xcape -e "Control_L=Escape"
      '';
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };
}
