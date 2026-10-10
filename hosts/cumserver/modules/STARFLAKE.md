# Starflake on cumserver

## Architecture and deployments

`starflake.nix` configures independent application releases without rebuilding NixOS for each release. NixOS owns runtime identities, agenix secrets, state directories, sandboxing and backups. An unprivileged worker resolves/builds each source; a separate root controller switches its fixed Nix profile and verifies runtime health. Application units are `starflake-app-NAME.service`; controller configuration is `/etc/starflake/NAME.json`.

| Deployment | Source | Persistent data | Release policy |
| --- | --- | --- | --- |
| `reactor` | `github:sleroq/reactor/main`, package `default` | `/var/lib/reactor` | Local builds allowed; 3 retained generations |
| `bayan` | `github:sleroq/bayan/main` | `/var/lib/bayan` | Cache-only builds; 3 retained generations |
| `spoiler-images` | `github:sleroq/spoiler-images/master` | Stateless | Default build/retention policy |

All three poll every 10 minutes and have host-owned initial packages. Initial packages bootstrap deployments without an existing journal; they do not overwrite active releases. No new firewall ports are exposed. Reactor and Bayan data have Restic backups configured in `default.nix` and `starflake.nix`, respectively.

## Controller source and host deployment

The **current** controller input is an unpublished immutable source snapshot pinned in `flake.nix`/`flake.lock`, not a permanent distribution requirement. `system.extraDependencies` retains its source on cumserver for future evaluations. On a fresh machine, copy the pinned source from cumserver before evaluating the host configuration, for example `nix copy --from ssh://cumserver PINNED_SOURCE_STORE_PATH`, using the path in the current lock file.

To update from a local Starflake checkout, run its Go/static checks and Linux VM check, then archive it with `nix flake archive --json path:$HOME/develop/starflake`. Set `inputs.starflake.url` to the returned immutable `path` and update only that input's lock (`nix flake update starflake`). Build/deploy with `--build-host cumserver --target-host cumserver`; do not build the full server locally. Replace this snapshot workflow with a published Git revision when the controller has a remote repository.

Application releases require neither a dotfiles lock update nor a NixOS rebuild. Runtime configuration and secret changes still require a host deployment.

## Operations and recovery

Run control commands as root on cumserver; substitute any configured deployment name for `bayan`:

```sh
sudo starflake status bayan
sudo starflake history bayan
sudo starflake reconcile bayan
sudo starflake pause bayan
sudo starflake resume bayan
sudo starflake retry bayan
sudo starflake rollback bayan
journalctl -u starflake-reconcile-bayan -u starflake-build-bayan -u starflake-app-bayan
```

`status` and `history` display JSON state. `reconcile` runs a reconciliation; unchanged healthy polls do not restart the app. `pause` suspends automatic updates, while `resume` re-enables discovery. `retry` clears rejection so an unchanged failed candidate can be attempted again; normal polling deduplicates rejected identities. `rollback` selects retained known-good history and pauses updates so polling does not immediately reverse it.

Failed builds leave the active release running. Failed activation restores and verifies the previous profile; first-release failure stops the app. Interrupted transactions are recovered before another build. If rollback health fails, retain the journal and investigate rather than deleting controller state.

**Rollback restores binaries only**, not application data, credentials or host configuration. Verify backups and schema compatibility before releases that change persistent data; any data restoration is a separate operator recovery action. Do not delete profiles, journals, generations or backups as a troubleshooting shortcut, and do not run a second instance against the same bot credentials/state.

## Metrics and dashboard diagnostics

Prometheus scrapes cumserver's read-only loopback exporter at `127.0.0.1:9598`; the scrape configuration also includes Div and Roundy on port 9599. Do not expose the exporter publicly: it contains revision and operational information and has no control API.

```sh
curl -fsS http://127.0.0.1:9598/metrics
```

The [Starflake dashboard](https://cum.army/grafana/d/starflake/starflake) is provisioned from `monitoring/dashboards/starflake.json` using `Prometheus1` and `Loki1`. Filter by host/deployment to inspect health, update state, read errors, revisions, attempt timing and action outcomes. Logs show cumserver journal streams filtered by deployment; the host filter applies to metrics, not logs.

For an unhealthy deployment, inspect `starflake_service_healthy`, `starflake_read_error`, status/history and the three unit journals above. For stale reconciliation, check the last-attempt timestamp and polling/paused state; dashboard freshness is amber after 15 minutes and red after 30 minutes. Last-success time tracks releases, not unchanged healthy polls, so release age alone is not a stalled-poller signal. Process health is not application readiness, and recorded duration is not a full deployment histogram.

If dashboard metrics or logs disappear, check the exporter response, Prometheus scrape health and actual Loki ingestion as well as readiness. Loki's filesystem WAL guard can reject writes above its usage threshold even while `/ready` succeeds; inspect storage headroom and ingestion errors rather than disabling the guard or deleting retained data.
