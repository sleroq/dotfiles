# Starflake on cumserver

Starflake deploys applications independently of NixOS rebuilds. Runtime configuration and secrets still require a host deployment. Fumo currently uses a local source snapshot; see [FUMO_GATEWAY.md](FUMO_GATEWAY.md) for its deployment workflow.

The controller is pinned to an unpublished source snapshot. On a fresh machine, copy the pinned store path from cumserver before evaluating the host configuration: `nix copy --from ssh://cumserver PINNED_SOURCE_STORE_PATH`. To update it, archive a tested local checkout with `nix flake archive --json path:$HOME/develop/starflake`, set `inputs.starflake.url` to the returned path, and update the input lock with `nix flake update starflake`.

## Operations

Run on cumserver, substituting the deployment name:

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

`retry` allows a rejected candidate to be attempted again; `rollback` selects a known-good release and pauses updates. **Rollback restores binaries only**, not application data, credentials or host configuration. Check backups and schema compatibility before releases that change persistent data.

The [Starflake dashboard](https://cum.army/grafana/d/starflake/starflake) shows deployment metrics and logs. Its host filter applies to metrics, not logs. The loopback exporter at `127.0.0.1:9598/metrics` has no authentication and must not be exposed publicly.
