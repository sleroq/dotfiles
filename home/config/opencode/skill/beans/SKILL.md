---
name: beans-issue-tracking
description: Use when starting work, tracking tasks, or deciding where to record discovered work - clarifies when to use TodoWrite vs Beans
---

## Task Tracking Systems

| System | Purpose | Persistence | Audience |
| :--- | :--- | :--- | :--- |
| **TodoWrite** | Live progress visibility | Session only | User |
| **Beans** | Agent memory & audit trail | Git-tracked | Agents, future sessions |

**Usage Guidelines:**

- **TodoWrite**: Use for multi-step (3+) user-facing work to show progress. Skip for background tasks.
- **Beans**: Use for all non-trivial work (3+ steps). Mandatory for audit trails and session-spanning tasks.
- **Granularity**: Avoid excessive splitting. Keep related context together to minimize CLI overhead and context fragmentation.
- Skip both for trivial single-step fixes (e.g., typos).

## Finding Work

When the user asks what to work on next:

```bash
# Find beans ready to start (not blocked, excludes in-progress/completed/scrapped/draft)
beans list --ready

# View full details of specific beans (supports multiple IDs)
beans show <id> [id...]

# Filter by priority and type
beans list -p high,critical -t bug,feature -s todo

# Search for work
beans list -S "authentication"
```

## Bean Types & Conceptual Hierarchy

Beans follows a structured hierarchy: **Milestone → Epic → Feature → Task/Bug**

| Type       | When to Use                                            | Example                              |
| ---------- | ------------------------------------------------------ | ------------------------------------ |
| `milestone` | Releases, major checkpoints, sprint boundaries         | "v1.0 Release", "Q4 Planning"        |
| `epic`     | Large initiatives, multi-feature work (weeks+)         | "User Authentication System"        |
| `feature`  | New capabilities, user-facing enhancements             | "OAuth Integration", "Dashboard"    |
| `bug`      | Broken functionality, defects to fix                   | "Login fails with special chars"     |
| `task`     | Chores, technical work, sub-tasks under epics         | "Add unit tests", "Update deps"      |

## Task Granularity

Finding the right balance for task size is crucial for agent efficiency:

- **Avoid Over-Splitting**: Tasks should NOT be split too much. If a task contains enough information to be a logical, detailed unit of work, it should not be broken into multiple small tasks.
- **Context Efficiency**: Over-granular task splitting causes the agent to execute many more CLI commands to gather information instead of being able to read 1-2 mid-to-large files that contain the complete context.
- **The Balance**: Tasks should be appropriately sized—not so big they overwhelm, but not so small that context is fragmented and requires excessive navigation.

## Task Lifecycle

### 1. Before Starting

- Find work: `beans list --ready`
- Create bean: `beans create "Title" -t <type> -s in-progress`
- For user-facing work, also create a **TodoWrite** list mirroring the bean's checklist.

### 2. During Work

- **Update checklist immediately**: Mark items `- [x]` as finished. This provides persistence if context is lost.
- Keep TodoWrite items in sync with bean checklist items for consistency.

### 3. After Completion

- Mark completed: `beans update <id> -s completed`
- Add a `## Summary of Changes` section to the bean file.
- If scrapped, use `-s scrapped` and add a `## Reasons for Scrapping` section.

## Status Workflow

| Status      | When to Use                                                       |
| ----------- | ----------------------------------------------------------------- |
| `draft`     | Idea not ready to start - needs refinement or research            |
| `todo`      | Ready to start work - all prerequisites met, not blocked        |
| `in-progress` | Currently being worked on - actively editing files               |
| `completed` | All checklist items done - ready for code review and commit      |
| `scrapped`  | Abandoned - add "## Reasons for Scrapping" section with reason    |

**Transitions:** `draft` → `todo` → `in-progress` → `completed`.

## Discovered Work

Never ignore discovered work. Create a bean immediately when new tasks are identified.

```bash
beans create "Title" --tag discovered -t task -s todo
beans create "Subtask" -t task --parent <current-id> --tag discovered
```

## Tags - Cross-Cutting Organization

Use tags for concerns not covered by type or hierarchy.

**Recommended tags:**

- `discovered` - Work found during implementation
- `frontend` / `backend` - Component type
- `security` / `performance` - Non-functional concerns
- `docs` - Documentation updates

```bash
beans create "Fix XSS" -t bug --tag security --tag backend
beans list --tag security
```

## Git Integration

Every code commit includes its associated bean file:

```bash
git commit -m "[TYPE] Description" -- src/file.ts .beans/issue-abc123.md
```

When closing a bean, reference it in the commit message:

```
<descriptive message>

Closes beans-1234.
```

## CLI Reference

```bash
# Creating beans
beans create "Title" -t task -d "Description" -s todo
beans create "Title" -t task --parent <parent-id>

# Updating beans
beans update <id> -s in-progress
beans update <id> --parent <id>
beans update <id> --blocking <id>

# Maintenance
beans check
beans archive
```

## Advanced Tools

**Roadmap Generation**

```bash
beans roadmap > ROADMAP.md
```

**Interactive Management**

```bash
beans tui
```

Use `beans <command> --help` for full options or `beans prime` for comprehensive training.

## Troubleshooting

- **Context Lost**: Use `beans list -s in-progress` to find active work and `beans show <id>` to resume from the checklist.
- **Broken Dependencies**: Run `beans check` for cycles or orphans. Use `beans list --has-blocking` to see blockers.
- **Corrupted Files**: Run `beans check --fix` or manually inspect `.beans/` files.
- **Overload**: Use `beans roadmap` for a high-level view and `beans archive` to clean up.

## Best Practices Summary

- **Always** create a bean for non-trivial work (3+ steps) and use the hierarchy (Milestone → Epic → Feature → Task).
- **Maintain balanced granularity**: Keep tasks large enough to preserve context but small enough to be manageable. Avoid over-splitting.
- **Update checklists immediately** after finishing a step to maintain persistence.
- **Include bean files** in git commits.
- **Use `draft`** for ideas and `--parent` / `--blocking` for relationships.
- **Never ignore discovered work**; create beans immediately.
- **Run `beans list --ready`** to find your next task.

## Relationships

**Parent**: Hierarchy (milestone → epic → feature → task/bug). Set with `--parent <id>`.

```bash
# Create epic
beans create "Authentication System" -t epic -s todo

# Create features under epic (use epic ID from output)
beans create "OAuth Integration" -t feature -s todo --parent <epic-id>
beans create "Session Management" -t feature -s todo --parent <epic-id>

# Create tasks under feature
beans create "Implement Google OAuth" -t task -s todo --parent <feature-id>
```

**Blocking**: Dependencies. Set with `--blocking <id>` to indicate this bean blocks another.

```bash
# Create migration
beans create "Migrate DB to PostgreSQL" -t task -s todo

# Create feature that depends on migration
beans create "User profiles" -t feature -s todo

# Mark migration as blocking feature
beans update <migration-id> --blocking <feature-id>

# Filter by blocking status
beans list --is-blocked      # Beans that cannot start (blocked by others)
beans list --has-blocking    # Beans that block others (are blockers)
beans list --ready           # Beans NOT blocked (ready to start)
```
