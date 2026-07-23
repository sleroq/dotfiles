---
# dotfiles-8aa5
title: Configure legacy Marzban subscription links in Remnawave
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

Preserve existing Marzban subscription URLs during cutover by configuring the Remnawave subscription-page service already modeled in `hosts/cumserver/modules/remnawave.nix`.

## Work

- [ ] Retrieve Marzban's legacy `secret_key` from its SQLite database at `/var/lib/marzban/db.sqlite3` (query: `SELECT secret_key FROM jwt LIMIT 1;`).
- [ ] Generate a dedicated Remnawave API token for the subscription page.
- [ ] Put `MARZBAN_LEGACY_LINK_ENABLED=true`, `MARZBAN_LEGACY_SECRET_KEY`, `REMNAWAVE_API_TOKEN`, and the existing Marzban path as `CUSTOM_SUB_PREFIX` in the encrypted `remnawaveSubscriptionPageEnv` secret; do not commit plaintext values.
- [ ] Enable `cumserver.remnawave.subscriptionPage` and retain `uwu.sleroq.link` as its domain so the existing Caddy legacy-path routing continues to serve old links.
- [ ] Deploy/recreate `remnawave-subscription-page` and inspect its logs for configuration or API errors.
- [ ] Test representative old Marzban subscription links, including client-specific rendering/assets, against the Remnawave page.

All four legacy variables are required when `MARZBAN_LEGACY_LINK_ENABLED=true`.

## Acceptance criteria

- [ ] Existing `/sub/...` links resolve without changing their URLs and return the matching Remnawave user data.
- [ ] The legacy secret and API token exist only in encrypted/runtime secret storage.
- [ ] Normal Marzban panel routes remain available until the final cutover.
