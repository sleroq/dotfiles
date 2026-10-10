---
# dotfiles-1n8i
title: DWL aborts on initial maximize requests from Nemo and Filelight
status: completed
type: bug
priority: normal
tags:
    - discovered
created_at: 2026-10-10T00:46:30Z
updated_at: 2026-10-10T01:14:25Z
---

Physical-session coredumps for Meta+Y/Nemo and Filelight reach maximize_client -> wlr_xdg_toplevel_set_maximized -> wlr_xdg_surface_schedule_configure, asserting surface->initialized. Initial client maximize requests can arrive before the initial surface commit. Fix protocol initialization ownership, preserve requested maximize state and initial geometry, and protect the real initial-request lifecycle with a regression.

Guard uninitialized XDG maximize requests and consume requested maximization during the first commit, before sending initial configure. Regression reproduces the exact initialized assertion on the installed old compositor and passes on the fix, including native 1202x716 acknowledgement and repeated 500x300 restoration. Real Nemo/Filelight map in a private headless/D-Bus runtime. C boundary harness and complete system build pass; deployed persistently without restarting the active WM.
