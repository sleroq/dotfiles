---
# dotfiles-00k3
title: Prepare cumserver for Marzban-to-Remnawave migration
status: todo
type: task
priority: high
tags:
    - remnawave
    - migration
created_at: 2026-07-23T07:40:54Z
updated_at: 2026-07-23T07:40:54Z
---

Move the existing Marzban users to the Remnawave service declared in `hosts/cumserver/modules/remnawave.nix`. Prepare the destination and collect the required migration inputs without committing plaintext secrets.

## Work

- [ ] Create and verify a fresh restic backup of `/var/lib/marzban`; record how to restore it before proceeding.
- [ ] Enable and deploy `cumserver.remnawave`, then verify the backend, PostgreSQL, Valkey, Caddy route, and backup job are healthy.
- [ ] Obtain a Remnawave API token from the dashboard and the Marzban admin credentials.
- [ ] Decide which internal/external squad UUIDs migrated users should receive.
- [ ] Download and extract the current Linux amd64 release of `remnawave-migrate` from https://github.com/remnawave/migrate/releases into a temporary server working directory; record the exact version used.
- [ ] Confirm the migration host can reach both panel URLs and run the migration binary.
- [ ] If Caddy/Auth Portal protects the Remnawave API, issue an API key and plan to pass it as `--dest-headers="X-Api-Key:<key>"`.

## Migration inputs

Required flags are `--panel-type=marzban`, `--panel-url`, `--panel-username`, `--panel-password`, `--remnawave-url`, and `--remnawave-token`. Relevant optional flags include `--preserve-status`, `--preserve-subhash`, `--internal-squad`, `--external-squad`, `--preferred-strategy`, and `--dest-headers`.

Do not place credentials or tokens in this bean, the repository, or shell history.

## Acceptance criteria

- [ ] A restorable source backup exists.
- [ ] Remnawave is reachable and healthy while Marzban remains available.
- [ ] All credentials, tokens, squad choices, URLs, and the migration-tool version needed for a pilot are available securely.
