---
# dotfiles-vpu1
title: DWL screen sharing has no configured portal chooser
status: completed
type: bug
priority: normal
tags:
    - discovered
created_at: 2026-10-10T13:11:20Z
updated_at: 2026-10-10T13:52:48Z
---

OBS portal selection fails: xdg-desktop-portal-wlr logs missing wofi/rofi/bemenu/mew/fuzzel and no output found. Backend config is empty and default chooser cannot reliably find an installed chooser. Configure an absolute tofi dmenu chooser for the DWL-enabled wlr backend and verify portal selection plus PipeWire frames.


## Resolution

Configured the DWL-enabled wlr backend to use tofi in dmenu mode via an absolute Nix store path. Default chooser failed because its systemd service PATH excludes per-user desktop launchers. Hyprland portal routing is unchanged.

Nixfmt, deadnix --fail, nixf-tidy --variable-lookup (no diagnostics), full interplanetary build, and whitespace checks passed. Shared ast-grep still crashes with exit 139 (existing dotfiles-q7v1).

Verified actual physical DWL session: chooser launch and selection, CreateSession/SelectSources/Start/OpenPipeWireRemote, and five video buffers to GStreamer fakesink for both DP-1 at 2560x1440 and dedicated Kitty fixture window; no pictures/recordings saved. Initial probe consumer error was unconstrained ANY caps, resolved by video/x-raw capsfilter; no PipeWire policy/compositor modifications needed.

Live fix uses user runtime drop-in /run/user/1000/systemd/user/xdg-desktop-portal-wlr.service.d/zz-dwl-chooser.conf; only portal services restarted, compositor unchanged. Full system built at /tmp/dwl-portal-system; persistent activation awaits root tmux session, absent at completion. Runtime override expires on reboot. Probe logs: /tmp/dwl-portal-live-monitor-result.log and /tmp/dwl-portal-live-window-result.log.
