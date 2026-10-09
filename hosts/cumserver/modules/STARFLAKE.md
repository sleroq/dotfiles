# Starflake on cumserver

`starflake.nix` migrates `spoiler-images` (stateless) and `bayan` (existing `/var/lib/bayan`) to independent application profiles. Existing runtime identities, agenix secrets and Bayan Restic backups are retained. Neither service exposes a new firewall port. Prometheus scrapes the loopback exporter on port 9598.

The controller is currently an unpublished, immutable source snapshot pinned in `flake.nix`/`flake.lock`. Its source is kept in `system.extraDependencies`, so cumserver can evaluate the same input without a macOS checkout. To install the dotfiles on a fresh machine, copy that pinned source store path from cumserver first. Also copy the content-addressed Sieve compatibility snapshot referenced in `hosts/cumserver/default.nix`; the existing Sieve input expects different secret variable names, so this migration deliberately preserves the running binary rather than downgrading it. Replace this input with a published Git revision when Starflake has a remote repository.

To upgrade the controller from `~/develop/starflake`: run its Go/static checks and Linux VM check, archive it with `nix flake archive --json path:$HOME/develop/starflake`, set `inputs.starflake.url` to the returned immutable `path`, and update only that input's lock. Build/deploy with `--build-host cumserver --target-host cumserver`.

Application releases need no dotfiles lock update or NixOS rebuild:

```sh
ssh cumserver 'starflake status bayan'
ssh cumserver 'starflake reconcile bayan'
ssh cumserver 'starflake status spoiler-images'
ssh cumserver 'curl -fsS http://127.0.0.1:9598/metrics'
```

## Grafana dashboard

[Starflake](https://cum.army/grafana/d/starflake/starflake) is provisioned from `monitoring/dashboards/starflake.json` by the existing Grafana dashboard provider. It uses the `Prometheus1` and `Loki1` datasources; no additional exporter port or datasource is needed.

Filter by host and deployment. Five fleet-level summary cards stay the same size as services are added; the sortable fleet table puts health, release/update state, read errors, outcome, revision and timing on one row per host/deployment. Unhealthy rows sort first. A health timeline makes outages visible, and action rates are aggregated by action rather than drawing one line per service. The log panel shows cumserver journal streams only (these streams have no host label), filtered by deployment; the host filter applies to metrics, not logs. Freshness turns amber after 15 minutes and red after 30 minutes, based on the current 10-minute polling interval. Release age is informational: unchanged healthy polls do not advance the last successful release timestamp. Process health is not application readiness, recorded duration is not a full deployment histogram, and binary rollback does not restore data.

The Loki capacity incident is resolved: filesystem headroom was restored and fresh Starflake journal streams are flowing again. Loki's WAL guard rejects writes above its 90% usage threshold with the misleading `Ingester is shutting down` error even when `/ready` succeeds, so verify actual ingestion as well as readiness if this recurs. Do not disable the guard or remove existing generations/backups without approval.

## Migration recovery

The migration's stopped-state Bayan backup is `/root/starflake-migration-20260930/bayan`; original system/package GC roots are `starflake-migration-system` and `starflake-migration-bayan`. Keep them until recovery is independently verified; no server-wide garbage collection was performed. Kopoka has been retired from the host configuration at the operator's request; its encrypted secret is retained for a possible future return.

`starflake pause`, `resume`, `retry` and `rollback` operate on a named deployment. Rollback pauses automatic updates and restores binaries only, not application data. Do not start the obsolete `bayan.service`/`spoiler-images.service` alongside `starflake-app-*`; duplicate Telegram pollers conflict.
