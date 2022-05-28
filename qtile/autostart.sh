#!/bin/bash

run() {
  if ! pgrep -f "$1" ;
  then
    "$@"&
  fi
}


run sleep 2

# For sudo apps (disk mounting)
run /usr/lib/polkit-kde-authentication-agent-1

# Conpositor
run picom

# Screenshots
run flameshot

# Network control
run nm-applet

# Sound control
run pasystray -g

# Wallpapers
feh --bg-max -z -r ~/Sync/валпаперс
