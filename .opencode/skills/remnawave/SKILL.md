---
name: remnawave-operations
description: Operate Remnawave panels, nodes, profiles, subscriptions and deployments.
---

# Remnawave operations

- Use the **panel API**, with its deployed OpenAPI contract, for control-plane
  changes. Never write its database directly; read-only SQL is a diagnostic fallback.
  Nix owns host networking, containers, certificates, secrets and persistence.
- Decrypt `hosts/cumserver/secrets/remnawaveToken` via the age-secrets workflow into
  a private temporary file. Never expose tokens, subscriber links, keys or raw configs
  in logs/arguments; remove plaintext afterward.
- Trace references: profile → inbound → node/published host/squad → user → subscription.
  Fetch complete objects, preserve unrelated fields, and check dependent assignments.
- Deploy both sides of a new node: panel activation plus host runtime/credentials.
  Diagnose through API state → resolved node config/listeners/logs → **actual generated
  subscription** → authenticated client handshake; handwritten configs hide generator bugs.
- Back up persistence and affected API objects before destructive/bulk changes.
  Keep rollback until live verification passes; stage listeners on free ports if practical.
- Disable retired profiles/subscriptions; do not retain legacy listeners or hosts just
  for cached client configs. Verify migrated subscriptions expose only intended entries.
- Verify node connectivity, real client traffic and affected restart recovery, not
  merely active services. See `hosts/cumserver/REMNAWAVE.md` for client compatibility.
