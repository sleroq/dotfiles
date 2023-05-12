#!/usr/bin/env bash

set -e

current_workspace=$(swaymsg -t get_workspaces | jq '.[] | select(.focused==true) | .num')
initial_workspace=$((current_workspace / 11))

swaymsg move container to workspace $initial_workspace

swaymsg workspace number $initial_workspace

swaymsg mode default
