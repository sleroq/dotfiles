---
name: remnawave-operations
description: Operate and support Remnawave panels and nodes, including profiles, inbounds, hosts, squads, users, subscriptions, deployments, diagnostics, backups, and recovery.
---

# Remnawave Operations

Use this skill for Remnawave configuration, deployment, migration, and troubleshooting.

## Sources of truth

- Prefer the **panel API** for control-plane reads and writes. It validates the deployed contract and preserves Remnawave's relationships and side effects.
- Discover routes and payloads from the deployed panel's OpenAPI document or matching backend version; online examples may target another release.
- Use the repository and live host for containers, networking, certificates, secrets, and persistence.
- Use the node CLI to inspect the resolved runtime configuration or perform supported recovery. Query the database only as a read-only diagnostic fallback when the API cannot answer; never manage Remnawave by writing directly to it.

The repository's API token is stored as age-encrypted plaintext in `hosts/cumserver/secrets/remnawaveToken`. Follow the age-secrets workflow: decrypt it only into a mode-0600 temporary or root-only runtime file, use it as a bearer token without placing it in arguments or logs, then remove the plaintext. Do not reuse application tokens when a separately scoped operator token is appropriate.

## Operating model

Start by recording deployed versions and inventorying the relevant objects. Follow references rather than names:

```text
profile → inbound ─┬→ node activation
                   ├→ published host
                   └→ squad access → user → generated subscription
```

- To inspect stale or unexpected node configuration, compare the API's desired profile and inbound assignments with the node's resolved configuration, certificates, listeners, and current logs.
- Manage users, squads, hosts, nodes, and profiles through their API resources. Fetch the complete current object before changing it and preserve unrelated fields and references.
- Give nodes different behavior by assigning separate profiles or inbound sets, then verify every dependent host and squad still points to the intended inbound.
- When adding a node, configure both sides: create and activate it in Remnawave, deploy its runtime and credentials on the host, then prove connectivity and public listeners.
- For client failures, trace control plane → node runtime → generated subscription → client handshake. Always inspect a real generated subscription; a hand-written client config can hide generator problems.

## Safety and completion

- Never expose API tokens, node secrets, private keys, user identifiers, subscription URLs, generated configurations, or raw config dumps.
- Back up persistence before destructive, bulk, certificate, profile, or recovery changes. Keep a tested rollback until live verification passes.
- Stage listener changes on a free port where practical.
- After changes, verify API state, node connection and listeners, current logs, generated subscriptions, real client traffic, and restart recovery at the scope affected.
