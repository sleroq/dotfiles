{ pkgs, ... }:

let
  micMuteScript = pkgs.writeShellScriptBin "mic-mute-toggle" ''
    #!/usr/bin/env bash
    
    # Toggle microphone mute state
    pactl set-source-mute @DEFAULT_SOURCE@ toggle
    
    # Get current mute state
    is_muted=$(pactl get-source-mute @DEFAULT_SOURCE@ | grep -q "yes" && echo "true" || echo "false")
    
    # Send notification with appropriate icon and message
    if [ "$is_muted" = "true" ]; then
        notify-send "Microphone" "Muted" --icon=microphone-sensitivity-muted --urgency=low
    else
        notify-send "Microphone" "Unmuted" --icon=microphone-sensitivity-high --urgency=low
    fi
    
    # Update eww state if eww is running
    if pgrep -x "eww" > /dev/null; then
        eww update mic_muted=$is_muted || true
    fi
    
    exit 0
  '';
in
{
  home.packages = with pkgs; [
    micMuteScript
    libnotify  # for notify-send
  ];
} 
