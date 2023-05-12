#!/usr/bin/env bash

set -e

current_workspace=$(swaymsg -t get_workspaces | jq '.[] | select(.focused==true) | .num')
fullscreen_workspace=$((current_workspace * 11))

swaymsg move container to workspace $fullscreen_workspace

swaymsg workspace number $fullscreen_workspace

swaymsg mode maximize
