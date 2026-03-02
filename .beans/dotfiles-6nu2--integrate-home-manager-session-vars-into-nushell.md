---
# dotfiles-6nu2
title: Integrate Home Manager session vars into nushell
status: completed
type: task
priority: normal
created_at: 2026-03-02T07:39:20Z
updated_at: 2026-03-02T07:42:16Z
---

Implement IanHollow-style nushell integration so home.sessionVariables and home.sessionPath apply in nushell.

- [x] Update nushell env handling to load home.sessionVariables
- [x] Update nushell PATH handling to derive from home.sessionPath with deduplication
- [x] Verify Nix evaluation syntax with formatter/check

## Summary of Changes

- Ported IanHollow-style nushell integration into home/shared/shell.nix.
- Added nushell export bridge for home.sessionVariables via extraEnv (mkBefore).
- Added nushell ENV_CONVERSIONS and NU_LIB_DIRS bootstrap in extraConfig (mkBefore).
- Added PATH rebuild logic based on config.home.sessionPath with deduplication and platform-aware additions in extraConfig (mkAfter).
- Updated import call sites (home/shared/default.nix and home/hosts/portable.nix) to pass lib and config into shell.nix.
- Verified parse with nix-instantiate --parse home/shared/shell.nix.
- Full nix flake check --no-build is blocked by an unrelated upstream 404 for Anytype asset.
