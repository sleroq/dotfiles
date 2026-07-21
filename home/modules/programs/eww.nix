{ pkgs, lib, self, ... }:

with lib;
let
  ewwScripts = {
    getMicVolume = pkgs.writeShellScriptBin "eww-get-mic-volume" ''
      #!/usr/bin/env bash
      pamixer --default-source --get-volume
      exit 0
    '';

    getVolume = pkgs.writeShellScriptBin "eww-get-volume" ''
      #!/usr/bin/env bash
      if command -v pamixer &>/dev/null; then
          if [ true == "$(pamixer --get-mute)" ]; then
              echo 0
              exit
          else
              pamixer --get-volume
          fi
      else
          amixer -D pulse sget Master | awk -F '[^0-9]+' '/Left:/{print $3}'
      fi
    '';

    micMuteStatus = pkgs.writeShellScriptBin "eww-mic-mute-status" ''
      #!/usr/bin/env bash
      pamixer --default-source --get-mute
      exit 0
    '';

    micUseStatus = pkgs.writeShellScriptBin "eww-mic-use-status" ''
      #!/usr/bin/env bash
      pactl list sources | grep -c 'State: RUNNING'
      exit 0
    '';
  };
in
{
  programs.eww = {
    enable = true;
    yuckConfig = builtins.readFile (self + /home/config/eww/bar/eww.yuck);
    scssConfig = builtins.readFile (self + /home/config/eww/bar/eww.scss);
  };

  xdg.configFile."eww/scripts".source = self + /home/config/eww/bar/scripts;

  fonts.fontconfig.enable = true;
  home.packages = with pkgs; [
    gawk
    pamixer
    killall

    ewwScripts.getMicVolume
    ewwScripts.getVolume
    ewwScripts.micMuteStatus
    ewwScripts.micUseStatus

    pkgs.nerd-fonts.noto
    pkgs.nerd-fonts.daddy-time-mono
  ];
}
