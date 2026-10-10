---
# dotfiles-adgd
title: Overlay transient dialogs escape onto normal workspaces
status: completed
type: bug
priority: normal
tags:
    - discovered
created_at: 2026-10-09T23:51:10Z
updated_at: 2026-10-10T00:12:52Z
---

A real GTK modal fixture opened from an overlay parent remained visible after hiding the overlay, at the upper-left beneath the sidebar. Mapnotify inherited parent monitor/tags but not independent overlay membership, and initial floating placement excluded all transient children. Inherit parent overlay membership when mapping a transient and center its first floating rectangle relative to the parent; preserve subsequent rectangles and keep unrelated clients unchanged.

Fixed transient overlay inheritance before setmon, first-map centering relative to the parent, and exclusion of overlay dialog maps from underlying fullscreen cancellation. Real isolated GTK regression now checks ordinary-tag exclusion, hide/show focus and dialog-state retention, plus preservation of a separate fullscreen underlay. Compositor builds and C boundary harness pass.
