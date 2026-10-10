---
# dotfiles-viij
title: Correct DWL floating/group state transitions and add usable tabs
status: in-progress
type: bug
tags:
    - discovered
created_at: 2026-10-10T12:57:55Z
updated_at: 2026-10-10T12:57:55Z
---

User reports float-to-tile remains overlapping, floating/group keyboard navigation fails, grouped windows have no tab indication, and oversized floating windows snap back during movement. Audit ownership of maximize/floating state, visible focus enumeration, geometry bounds, and pane presentation; fix real transitions and add visible tab strips with focused runtime regression coverage.

Implemented: explicit float/tile/drag operations unmaximize; retile selects its grouped tab; grouped navigation falls back for floating/overlay clients and at pane boundaries; compositor-owned 26px Cairo/Pango title strips support click selection with matching rounded hit boundaries; ordinary floating positions retain one visible pixel rather than a full-size snapback. Overlay remains always floating. Title changes repaint decoration without rearranging windows.

Verified: real GTK transition regression (native maximize/restore, retile, J/K tabs, H/L panes, floating focus, tab/application clicks, strip reservation, oversized drag stable across commits/release); existing hover/transient/fullscreen regression; C boundary harness; package/system builds; Nix formatting/deadnix/nixf diagnostics; source whitespace checks. Shared ast-grep still crashes with exit 139 (dotfiles-q7v1).

The oversized fixture now sets 1800x1000 before map: GTK's spontaneous resize allocation did not change compositor-owned geometry, so that old fixture correctly received a 500x300 restore configure. No client-request sizing redesign was added.

Follow-up floating size memory implemented: Super+Shift+Space saves per-client floating dimensions before tiling and restores them on return, keeping current position. First-map natural dimensions seed the memory before tiling/maximization. Native regression confirms 500x300 restoration, interactive resize to 640x360, repeated tile/float cycles, and no overwrite by maximization. Existing headless regressions, C harness, package and system builds passed.

Corrected the virtual-pointer fixture's relative motion arguments to Wayland fixed-point values: raw integers had silently reduced drag distance by 256. The enhanced regression exercises actual 140x60 resize deltas and 3000px attempted drag motion.

Pending deployment: root tmux is unavailable. Latest built system is `/tmp/dwl-window-system` -> `/nix/store/a6y0qr7gp7d1a7j1rzddixlgpjnapvls-nixos-system-sleroq-interplanetary-26.11.20261007.39ad350`; compositor is `/tmp/dwl-compositor` -> `/nix/store/g0mfq7hi45p5rixkbrsgdgr7wg90n4qk-dwl-0.9`. Non-disruptive activation and then user relogin required; recheck the running binary before deployment.
