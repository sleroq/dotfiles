---
# dotfiles-ql36
title: Eww lock action can kill foreground swaylock and strand DWL locked
status: in-progress
type: bug
priority: normal
tags:
    - discovered
created_at: 2026-10-10T13:04:14Z
updated_at: 2026-10-10T13:13:35Z
---

Historical session shutdown completed and SDDM returned04:18:44; user logged in again04:18:50. Eww later logged foreground swaylock action timeout04:20:17. Its action runner kills the immediate child on timeout; Bash execs a lone swaylock command. DWL intentionally retains a gray fail-closed background and disables compositor bindings when locker dies. Use swaylock -f for the sidebar action, label it Lock rather than a power/logout symbol, and validate locker lifetime/death plus compositor SIGTERM in an isolated backend. Exact attribution of reported logout gray screen remains unproven.

Pinned Eww button deadline is 200ms, not a session-lifetime deadline. Sidebar now invokes swaylock -f with a 10s startup timeout and explicitly labels Lock. New isolated lock.py uses the real sidebar callback with a 300ms startup delay: daemon remains after11s; killing owned locker reproduces 1280x720 RGB(25,25,25) fail-closed gray; SIGTERM exits locked compositor in3ms. Two runs and full system build pass. Normal PAM unlock, physical logout, and exact historical attribution remain untested; deployment awaits recreated root tmux session after reboot. Existing previous-boot UWSM teardown returned SDDM normally.
