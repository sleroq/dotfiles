#!/usr/bin/env bash

exec waybar &
exec mako &
exec nm-applet --indicator &
exec gammastep-indicator &

exec hyprpaper &

hyprctl dispatch exec '[workspace 1 silent] librewolf'
hyprctl dispatch exec '[noanim;float;workspace 5 silent] keepassxc'

notify-send -a aurora "hello $(whoami)" &
