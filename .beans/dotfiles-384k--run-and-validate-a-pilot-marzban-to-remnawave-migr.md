---
# dotfiles-384k
title: Run and validate a pilot Marzban-to-Remnawave migration
status: todo
type: task
priority: high
tags:
    - remnawave
    - migration
created_at: 2026-07-23T07:41:13Z
updated_at: 2026-07-23T07:41:13Z
blocked_by:
    - dotfiles-00k3
---

Use a small sample to prove the migration settings and data mapping before touching the full user set.

## Work

- [ ] Record source and destination user counts before the pilot.
- [ ] Run `remnawave-migrate` with the prepared required flags plus `--last-users=5`, `--preserve-status`, and `--preserve-subhash`.
- [ ] Apply the chosen `--internal-squad` and/or `--external-squad` values.
- [ ] Add `--dest-headers="X-Api-Key:<key>"` if the destination is protected by the Caddy Auth Portal.
- [ ] Leave `--preferred-strategy` unset to preserve source reset strategies unless a deliberate override has been chosen; note that source `YEAR` becomes `NO_RESET`.
- [ ] Capture sanitized output and document any warnings or mapping decisions without storing credentials.
- [ ] Compare all five users in both panels: username, Trojan/VLESS/Shadowsocks credentials, traffic limit, reset strategy, expiration, status, subscription hash, and squad assignments.
- [ ] Remove or otherwise account for pilot-created destination users before the full run so they cannot become duplicates.

## Acceptance criteria

- [ ] Every pilot user is represented correctly in Remnawave.
- [ ] The exact sanitized command options for the full migration are recorded.
- [ ] The destination is in a known state with no unexplained duplicate users.
