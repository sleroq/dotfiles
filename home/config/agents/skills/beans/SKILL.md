---
name: issue-tracking-with-beans
description: Use when starting work, tracking tasks, or deciding where to record discovered work with Beans
---

# Issue Tracking With Beans

Beans is the persistent issue-tracking system for agent work. Use it to keep agent memory, recoverable progress, and audit history in git-tracked files.

## When to Use Beans

- All non-trivial work (3+ steps)
- Work that may span sessions or context boundaries
- Discovered work during implementation
- Anything needing an audit trail
- Skip for trivial single-step tasks (typo fixes, quick lookups, planning or design)

## Rule: Create a Bean Before Non-Trivial Work

For non-trivial work:

1. Create a bean first (`beans create ... -s in-progress`)
2. Add checklist items that reflect the work to be done
3. Update the bean as you progress
4. Keep checklist items specific enough to serve as recoverable checkpoints

## Rule: Update Bean Checklists Immediately

After completing each checklist item in a bean:

1. Edit the bean file: `- [ ]` → `- [x]`
2. This creates a recoverable checkpoint if context is lost
3. The I/O overhead is acceptable for persistence

## Rule: Commit Bean Changes With Code

Every code commit includes its associated bean file updates:

```bash
git commit -m "[TYPE] Description" -- src/file.ts .beans/issue-abc123.md
```

This keeps bean state synchronized with codebase state.

## Git Commit Messages

When closing a Beans issue, reference it in the commit:

```
<descriptive message>

Closes beans-1234.
```

## Rule: Discovered Work Goes to Beans

When you discover work during implementation:

1. Create a bean immediately (`--tag discovered`), add a line that explains that it was created while working on current bean, and name the current bean.
2. Never ignore discovered work due to context pressure
3. Label discovered issues appropriately for later triage

For epic-level discovered work, create the bean with `--type epic`.

## Querying Work

- `beans list --status backlog` — Find unblocked work to do next
- `beans show <id>` — View issue details including dependencies
