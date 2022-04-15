#!/usr/bin/env bash

function run {
  if ! pgrep -f "$1" ;
  then
    $@&
  fi
}

run picom

run flameshot

run nm-applet

run pasystray -g
