---
description: Explain scoped code for correctness and maintainability
argument-hint: "[scope, new, staged, project, or instructions]"
---

Explain the scoped code from two perspectives so the user can review its correctness and maintainability; this is an explicitly invoked command rather than an automatically discoverable agent skill.

**Scope:** `$ARGUMENTS`

Interpret `new`/`unstaged` as working-tree plus untracked changes, `staged` as the index, `all changes` as both, `project` or no argument as the whole project, and otherwise resolve the named module, file, symbol, function, class, feature, commit, branch, range, PR, MR, or natural-language scope.
Ask one focused question only when competing interpretations would materially change the explanation.
Read beyond the diff to establish ownership, entry points, call paths, data contracts, state transitions, boundaries, and the surrounding implementation.
First explain the overall structure, component responsibilities, control/data flow, rationale, trade-offs, assumptions, and one credible alternative with why the current design was likely preferred.
Then trace a representative use case end to end in concrete domain terms: we want A, which requires B, obtained from C, processed by D under business rule E, persisted or synchronized as F, and delivered to the caller or user through G.
When client state is involved, identify the authoritative state, inputs/events, update mechanism, reconciliation rules, stale or conflicting state behavior, and what triggers rendering or downstream work.
For changes, distinguish existing architecture from what was added, removed, or rerouted, and explain behavioral consequences rather than merely listing edited symbols.
Ground claims with `path/to/file:line` links or ranges and short high-value snippets, using a Mermaid flow or sequence diagram when it clarifies meaningful shape.
Organize the answer as useful subsets of **Architecture and rationale**, **End-to-end execution**, **State reconciliation**, **Changes and consequences**, **Alternative design**, and **Review guide**, without narrating syntax or producing a file inventory.
