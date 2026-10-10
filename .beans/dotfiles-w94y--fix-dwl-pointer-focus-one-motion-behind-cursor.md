---
# dotfiles-w94y
title: Fix DWL pointer focus one motion behind cursor
status: completed
type: bug
priority: normal
tags:
    - discovered
created_at: 2026-10-09T23:18:14Z
updated_at: 2026-10-09T23:41:22Z
---

Actual headless Eww protocol tracing showed edge sensors and drawer leave lag one pointer event. DWL v0.9 motionnotify hit-tests the old cursor coordinates before moving, then forwards focus/motion to that old surface. Move ordinary hit-testing after cursor movement while retaining old-position constraint calculations and implicit pointer grabs; verify edge entry and delayed close with real Wayland pointer events.

Fixed ordinary hit-testing after movement while preserving old-position pointer constraint processing and pressed/grab behavior. Added packages/dwl/tests/hover.py: real isolated headless compositor/helper/Eww runs three single-motion entry/exit cycles for both edge drawers, passing without compensating motion. Compilation and existing boundary harness pass. Runtime also exposed and fixed a distinct helper sensor/content handoff ordering issue via independent hover-source tracking and a socket regression.
