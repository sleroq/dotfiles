# Roundy migration staging

**Production cutover is not authorized.** The bot and production Countly unit
must stay disabled until the owner explicitly approves the low-traffic window.

## Current preparation

- NixOS 26.05, installation `stateVersion = "25.11"`, kernel 6.18.54.
- `/dev/sda1` is **virtio-scsi**. Keep `virtio_scsi` in the initrd; its omission
  caused the first reboot failure. The UUID is verified against the live disk.
- SSH keys/host keys retained; password and keyboard-interactive SSH disabled.
- Native Roundy 3.8.2: Node 22.23.3, ffmpeg 8.1.2, pinned payment CA.
  Supplied checkout matches all 64 compared running-image source/package files.
- Separate Mongo 4.4.29 containers on localhost 27017/27018, initial logical
  restores completed. Countly retains its exact 19.08.1 image, Node 8.16.1 and
  Mongo 3.6.14; restored data is in `/var/lib/countly/data`.
- Bot dependencies/database reads, H.264/HEVC conversion and payment CA tested
  without starting the bot. Countly's isolated, network-disabled UI test passed;
  the temporary container was stopped.
- Grafana's existing Prometheus datasource sees `instance="Roundy"` for node
  metrics and `instance="roundy"` for Starflake. Both scrape targets are UP.
- Native Timeweb Zabbix settings retained. No provider installer was run.
- Daily encrypted R2 backups of `/var/backups/roundy`; Mongo dumps refreshed
  first, Countly refreshed when its production marker exists. First backup was
  read-checked, restored and SHA256-matched. Use `restic-roundy` as root.

These are **initial staging snapshots**, not a final migration of current live
writes. No polling, production DNS or payment callbacks have been switched.

## Public hostnames — DNS created, HTTPS deployment pending

Cloudflare DNS-only A records for `roundy.sleroq.link` and
`countly.sleroq.link` point to the `roundy` SSH target (address in encrypted
`secrets/default.nix`; TTL 300 seconds).
Existing production DNS and payment callbacks are unchanged.

Caddy's HTTPS staging declarations are ready: `/healthz` returns 200 and all
other requests return 503, without forwarding to either application. They have
**not been deployed**: `cumserver` SSH authentication currently fails, so the
remote dry activation stopped before building or activating the new system.
Restore builder access, review the dry activation, deploy and verify both TLS
certificates before treating these hostnames as ready.

## Deployment and boot verification

Use `nixos-rebuild` with `--build-host cumserver --target-host roundy`.
Never build on this 4 GB VPS (`max-jobs = 0`). On Darwin, use
`nixos-rebuild-ng` and `--no-reexec` so the Linux rebuild executable is not run
locally. New host files must be Git-visible for `--flake .#roundy`.

```sh
nixos-rebuild build --flake .#roundy --build-host cumserver --target-host roundy --no-reexec
nixos-rebuild boot --flake .#roundy --build-host cumserver --target-host roundy --no-reexec
```

`build` copies the closure without activating. `boot` only prepares the next
boot. After changing boot-critical configuration, run `check-initrd.sh` on
cumserver with the actual built kernel/initrd and the root UUID; provide
`QEMU=/path/to/qemu-system-x86_64`. It mounts a dummy virtio-scsi root disk,
**not a full NixOS system**. Broken and fixed artifacts were compared.

For the recovery trial, GRUB used the original 25.11 generation as its saved
fallback and booted the repaired system once via `grub-reboot 0`. The trial
passed; the normal default now points to the repaired 26.05 system. Keep the
working 25.11 generations; older 26.05 generations lack the disk driver.

Roundy and Starflake sources are immutable store inputs and preserved by
`system.extraDependencies`. A fresh operator machine without those private
snapshots can retrieve them with `nix copy --from ssh://roundy` using the paths
in `flake.lock`. Publish/restore private repository access before enabling
automatic application updates; polling and local application builds are off.

## Cutover prerequisites — separate owner approval required

1. Finish HTTPS staging deployment on the confirmed hostnames; prepare the
   approved proxy/callback transition and encrypt the new `TINKOFF_WEBHOOK`.
   Old in-flight payment notifications need an explicit forwarding/reconciliation
   plan. Do not assume CryptoCloud callbacks follow
   that environment variable.
2. Quiesce the old writers and acquire fresh logical dumps, including accounts,
   roles, other databases and indexes. Restore into staging before enabling it.
   Restoring admin accounts can invalidate an existing restore session: restore
   application namespaces/indexes separately from the final admin-account step.
3. Verify the refreshed data and backup, then activate Countly deliberately.
4. Only after approval and stopping the old poller, create Roundy's production
   marker, unpause Starflake and explicitly start the reconcile service.
   Never run old and new bot pollers together. Verify health/payments promptly;
   rollback requires stopping the new poller first and accounting for new writes.

The guards are `/var/lib/roundy/production-enabled` and
`/var/lib/countly/production-enabled`; both are absent. Starflake is paused,
its reconcile service has no automatic startup, and the Countly container has
`autoStart = false`. The public staging endpoint only offers `/healthz`; other
requests return 503.

## Repository privacy

Git-crypt protects `secrets/*.nix` and the private migration bean in public Git;
Roundy's runtime credential files remain agenix-encrypted. Unlock git-crypt
before evaluation, and verify staged Git ciphertext after adding attribute rules.

This does not hide addresses from public DNS or remove previously committed
plaintext from Git history. Evaluation metadata can enter `/nix/store`; keep
actual passwords and tokens in agenix files, not `secrets/default.nix`.
