#!/usr/bin/env bash

# Script is not relevant anymore, but useful for reference

handle() {
  case $1 in
    openwindow*)
      # Extract the window ID from the line
      window_id=$(echo ${1#*>>} | cut -d, -f1)

      # Fetch the list of windows and parse it using jq to find the window by its decimal ID
      window_info=$(hyprctl clients -j | jq --arg id "0x$window_id" '.[] | select(.address == ($id))')

      window_pid=$(echo "$window_info" | jq '.pid')
    
      pcmanfm_pid=$(pgrep pcmanfm-qt)

      if [[ "$window_pid" == "$pcmanfm_pid" ]]; then
        hyprctl --batch "dispatch togglefloating address:0x$window_id; dispatch resizewindowpixel exact 60% 60%,address:0x$window_id; dispatch movewindowpixel exact 20% 20%,address:0x$window_id" &
      fi
      ;;
  esac
}

# Listen to the Hyprland socket for events and process each line with the handle function
socat -U - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock | while read -r line; do handle "$line"; done
