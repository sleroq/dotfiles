---
# dotfiles-kvu0
title: Complete Marzban-to-Remnawave migration and cutover
status: todo
type: task
priority: critical
tags:
    - remnawave
    - migration
created_at: 2026-07-23T07:41:24Z
updated_at: 2026-07-23T07:41:24Z
blocked_by:
    - dotfiles-384k
    - dotfiles-8aa5
---

Migrate the complete Marzban user set with the pilot-proven options, validate it, and retire the old panel only after Remnawave and legacy links are confirmed healthy.

## Work

- [ ] Announce a migration window and prevent source changes while the final source count is recorded.
- [ ] Take and verify a final Marzban backup immediately before migration.
- [ ] Run `remnawave-migrate` for all users (`--last-users=0`, or omit it) using the exact pilot-proven URLs, credentials, status/subhash preservation, squad, reset-strategy, and destination-header options.
- [ ] Save sanitized migration output and reconcile successful, skipped, and failed records.
- [ ] Confirm destination user count matches the expected source total after accounting for any pre-existing/pilot users.
- [ ] Spot-check usernames, protocol credentials, traffic limits/reset strategies, expiration dates, statuses, subscription hashes, and internal/external squad assignments.
- [ ] Test new Remnawave subscriptions and representative legacy Marzban links end to end from real clients.
- [ ] Verify Remnawave backend/database/subscription-page health, Caddy routing, metrics, and a successful Remnawave backup.
- [ ] Disable `cumserver.marzban` only after all checks pass; retain its final backup and document the rollback window.
- [ ] Remove the migration binary/archive and any temporary files containing sensitive command arguments.

## Acceptance criteria

- [ ] Every expected user exists once in Remnawave with validated data.
- [ ] New and legacy subscription URLs work end to end.
- [ ] Remnawave is monitored and backed up, and Marzban is disabled with a tested rollback path retained.
