#/bin/bash

xrandr --output HDMI-1 --mode 1680x1050

# nitrogen --restore
feh --bg-scale --recursive --randomize --bg-fill Pictures/wallpapers/

# Notifications
dunst &

# Notifications
compton &

# Virtual box additions
# VBoxClient-all &

# Clipboard manager
/home/sloq/.local/share/dwm/start_clipmenud.sh &

flameshot &

# Safeeyes
# safeeyes &

dwmbar &
