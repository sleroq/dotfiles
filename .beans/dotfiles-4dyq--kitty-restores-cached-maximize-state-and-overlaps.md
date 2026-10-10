---
# dotfiles-4dyq
title: Kitty restores cached maximize state and overlaps tiled windows
status: completed
type: bug
priority: normal
tags:
    - discovered
created_at: 2026-10-10T01:10:18Z
updated_at: 2026-10-10T01:14:25Z
---

Live DWL monitor is ordinary []= layout with grouping off, but the Kitty client is maximized over the whole work area. Kitty cache main.json stores window-state=maximized. Kitty 0.49.2 ignores explicit --start-as normal when restoring cached state. Disable remember_window_size only on DWL terminal shortcuts; leave shared Kitty settings and Hyprland unchanged. Validate two real Kitty windows against a seeded maximized cache in isolation.

DWL Meta+Enter and Alt+Enter now pass --override remember_window_size=no, leaving global Kitty configuration and Hyprland untouched. Two actual Kitty processes with a seeded maximized cache render disjoint side-by-side rectangles in an isolated compositor. Full system built and deployed; active compositor will pick up compiled shortcut changes after relogin.
