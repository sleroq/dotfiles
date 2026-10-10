---
# dotfiles-q7v1
title: Shared ast-grep configuration crashes the scanner
status: todo
type: bug
tags:
    - discovered
created_at: 2026-10-09T22:19:46Z
updated_at: 2026-10-09T22:19:46Z
---

DWL configuration verification found ast-grep 0.45.3 exits 139 with the prescribed command: ast-grep scan --config "$HOME/sgconfig.yml" --no-ignore hidden . . It also crashes on --version from this repository; --version works from /tmp, but an explicit scan with /home/sleroq/sgconfig.yml still crashes there. The shared config registers a custom tree-sitter Svelte library; the cause is not yet isolated. Reproduces with the same package through nix-shell. Fix the shared scanner/config/parser compatibility rather than excluding files or rules. Nix formatting, deadnix, nixf-tidy and the DWL package build passed.
