{ pkgs, lib, opts, ... }:

with lib;
let
  # eww scripts extracted from config directories
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

    memory = pkgs.writeShellScriptBin "eww-memory" ''
      #!/usr/bin/env sh
      printf "%.0f\n" $(free -m | grep Mem | awk '{print ($3/$2)*100}')
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

    battery = pkgs.writeShellScriptBin "eww-battery" ''
      #!/usr/bin/env bash
      battery() {
      	BAT=$(ls /sys/class/power_supply | grep BAT | head -n 1)
      	cat /sys/class/power_supply/''${BAT}/capacity
      }
      battery_stat() {
      	BAT=$(ls /sys/class/power_supply | grep BAT | head -n 1)
      	cat /sys/class/power_supply/''${BAT}/status
      }

      if [[ "$1" == "--bat" ]]; then
      	battery
      elif [[ "$1" == "--bat-st" ]]; then
      	battery_stat
      fi
    '';
  };
in
{
  home.activation.eww = hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
        ${opts.realConfigs}/eww $HOME/.config
    
    # Create scripts directory with just eww-ws binary (other scripts are in PATH)
    mkdir -p $HOME/.config/eww/bar/scripts
    $DRY_RUN_CMD cp $VERBOSE_ARG \
        ${opts.realConfigs}/eww/bar/scripts/eww-ws $HOME/.config/eww/bar/scripts/ || true
  '';

  fonts.fontconfig.enable = true;
  home.packages = with pkgs; [
    eww
    gawk
    pamixer
    killall

    # eww scripts
    ewwScripts.getMicVolume
    ewwScripts.getVolume
    ewwScripts.memory
    ewwScripts.micMuteStatus
    ewwScripts.micUseStatus
    ewwScripts.battery

    pkgs.nerd-fonts.noto
    pkgs.nerd-fonts.daddy-time-mono
  ];
}
