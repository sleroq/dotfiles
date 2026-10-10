---
# dotfiles-q7v1
title: Shared ast-grep configuration crashes the scanner
status: completed
type: bug
priority: normal
tags:
    - discovered
created_at: 2026-10-09T22:19:46Z
updated_at: 2026-10-10T15:18:11Z
---

DWL configuration verification found ast-grep 0.45.3 exits 139 with the prescribed command: ast-grep scan --config "$HOME/sgconfig.yml" --no-ignore hidden . . It also crashes on --version from this repository; --version works from /tmp, but an explicit scan with /home/sleroq/sgconfig.yml still crashes there. The shared config registers a custom tree-sitter Svelte library; the cause is not yet isolated. Reproduces with the same package through nix-shell. Fix the shared scanner/config/parser compatibility rather than excluding files or rules. Nix formatting, deadnix, nixf-tidy and the DWL package build passed.

Resolved in packages/tree-sitter-htmlx-svelte.nix: compile the custom Svelte parser with -fno-strict-aliasing. GDB located the SIGSEGV in the vendored HTMLX scanner during tree-sitter tag-stack growth while ast-grep compiles the shared script injection patterns. Tree-sitter Array macros cast typed arrays through Array(void), so optimized strict-aliasing compilation miscompiles the contents update; no parser ABI change or ast-grep downgrade is needed.

Added install checks that load the built parser through ast-grep and compile/match both JavaScript and TypeScript script patterns. The fixed package builds and both checks pass; rebuilding the same package with only -fno-strict-aliasing removed fails the check with SIGSEGV/139. Documented the compiler requirement in home/config/ast-grep/README.md.

Built and activated only the generated shared and FRG configurations (GC-rooted home config links), not the full system. ast-grep --version now succeeds from this repository with both configurations. The prescribed repository-root shared scan exits 0. nixfmt, deadnix --fail, nixf-tidy --variable-lookup (no diagnostics), and targeted git diff --check pass.

The restored scan reports 29 existing TypeScript warnings in the direnv plugin and opencode-mcp extension/tests, with none in this change. Reviewed their messages and surrounding code: the runtime checks and unknown/dictionary types are JSON parsing boundaries, not narrowed trusted domain values; the optional common object is built incrementally; the test casts deliberately supply only the SDK members exercised by the extension, and unknown fixture values test malformed external JSON. Replacing these boundaries with trusted types or implementing the entire SDK mock would not improve the scanner fix. No rules, files, or findings were suppressed.
