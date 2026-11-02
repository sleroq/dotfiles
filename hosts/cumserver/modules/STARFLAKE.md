# Starflake operations

Application releases are separate from NixOS; runtime configuration/secrets still
require a host deployment. On cumserver, use `sudo starflake <command> <deployment>`:

- `status`, `history`, `reconcile`, `pause`, `resume`;
- `retry` re-attempts a rejected candidate; `rollback` selects a known-good release
  and pauses updates. **Binaries only:** check data/schema compatibility and backups.

Logs: `journalctl -u starflake-{reconcile,build,app}-<deployment>`.
[Dashboard](https://cum.army/grafana/d/starflake/starflake): host filtering covers metrics,
not logs. Never expose the unauthenticated loopback exporter on port 9598.

The controller uses a private immutable snapshot. Fresh operators must first
`nix copy --from ssh://cumserver PINNED_SOURCE_STORE_PATH` (see `flake.lock`).
To update, archive a tested checkout with `nix flake archive --json path:PATH`,
set `inputs.starflake.url` to its store path, then `nix flake update starflake`.
