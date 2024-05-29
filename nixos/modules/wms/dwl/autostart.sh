#!/usr/bin/env bash

exec dbus-sway-environment
exec systemctl --user start nixos-fake-graphical-session.target
exec configure-gtk
exec systemctl --user import-environment
exec kwalletd6

# exec aw-server # Activity watch server
exec flameshot
exec wl-paste --watch cliphist store
exec nm-applet --indicator

exec keepassxc
