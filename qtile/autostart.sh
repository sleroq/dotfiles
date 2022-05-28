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

run setxkbmap -layout us,ru -option grp:win_space_toggle

run picom

run flameshot

run nm-applet

run pasystray -g

feh --bg-max -z -r ~/Sync/валпаперс
