#!/usr/bin/env bash

set -e

launchctl bootout gui/$(id -u)/org.nix-community.home.activate-agenix 2>/dev/null || true
launchctl bootstrap gui/$(id -u) "$HOME/Library/LaunchAgents/org.nix-community.home.activate-agenix.plist"
launchctl kickstart -k gui/$(id -u)/org.nix-community.home.activate-agenix
