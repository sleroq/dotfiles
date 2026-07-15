---
name: issue-tracking-with-beans
description: Use when discovered unexpeted bug that needs fixing or asked by the user to create bean/task document
---

# Issue Tracking With Beans

Beans is the persistent issue-tracking system for agent work. Use it to keep agent memory, recoverable progress, and audit history in git-tracked files.

## When to Use Beans

- When asked by the user
- To track major future work that can't be done right now. For example discovered bug that requires a refactor

## Creating a Bean

`beans create ... -s todo`

Use tag discovered for discovered tasks to do later - `--tag discovered`

## Querying Work

- `beans list --status backlog` — Find unblocked work to do next
- `beans show <id>` — View issue details including dependencies
