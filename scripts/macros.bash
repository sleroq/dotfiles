#!/usr/bin/env bash

# Remap Caps Lock to Control when pressed alone
setxkbmap -option "ctrl:nocaps"

# Map Caps Lock + A/S/W/D to arrow keys
xmodmap -e "keycode 38 = Left"
xmodmap -e "keycode 39 = Down"
xmodmap -e "keycode 40 = Up"
xmodmap -e "keycode 41 = Right"

# Use xcape to reset Caps Lock functionality when released quickly
xcape -e "Control_L=Escape"
