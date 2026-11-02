# Roundy deployment and cutover

**Production cutover is not authorized.** Old production, DNS and payment callbacks
remain unchanged. Build/deploy rules are in [AGENTS.md](AGENTS.md).

## Current state

- Mongo main/log data is a live-copy rehearsal, not a consistent final migration.
  Countly retains its initial staging snapshot. Never merge test writes back.
- `roundy.sleroq.link` and `countly.sleroq.link` have HTTPS; `/healthz` returns 200,
  other routes return 503. Keep application/payment routes blocked during rehearsal.
- `roundy-test` is deployed but stopped. Production app/reconcile and Countly are
  inactive; Starflake is paused. Production markers are absent:
  `/var/lib/roundy/production-enabled`, `/var/lib/countly/production-enabled`.
- Daily R2 backups refresh Mongo dumps and include Countly when its marker exists.
  Use `restic-roundy` as root; verify restore/read-data before cutover.

## Deployment and recovery

```sh
nixos-rebuild dry-activate --flake .#roundy --build-host cumserver --target-host roundy --no-reexec
nixos-rebuild switch --flake .#roundy --build-host cumserver --target-host roundy --no-reexec
```

Review dry activation against the intended scope; do not blindly activate unrelated
lockfile updates. Use `boot` instead of `switch` when preparing the next boot.
Before boot-critical changes, run `check-initrd.sh SYSTEM UUID LOG` on cumserver
with `QEMU` set to its executable. It tests the built kernel/initrd's virtio-scsi
root mount, not full OS startup. Retain a verified working rollback generation.

Private immutable sources are preserved by `system.extraDependencies`. A fresh
operator can retrieve paths from `flake.lock` with `nix copy --from ssh://roundy`.
Restore repository access before enabling automatic application updates.

## Rehearsal gate

A **fresh production-artifact comparison is required before starting `roundy-test`**.
The preserved source export matches the packaged original source, but lacks current
production compiled output/dependencies. Request private CapRover or read-only Docker
access; a matching `/v` response alone is insufficient.

Use the approved tester-restricted mode and encrypted test environment, not just a
replacement bot token: ordinary startup can message copied users and create payments.
The test mode disables broadcasts, payments/callbacks and analytics, restricts incoming
updates/outgoing recipients to the tester, and uses target-local copied databases.

After artifact verification, explicitly start `roundy-test`; ask the owner to `/start`
and exercise menus/media conversion. This does not test payment settlement or production
channel permissions. Stop it before replacing rehearsal data. Require owner-confirmed
success before seeking separate low-traffic cutover approval.

## Cutover checklist — separate approval required

1. Preserve the exact old artifact/configuration and verified rollback backups.
   Review callback authentication/fulfillment with the owner (`dotfiles-095a`).
2. Plan old in-flight payment forwarding/reconciliation before changing
   `TINKOFF_WEBHOOK`; it affects new payments only. CryptoCloud changes are out of scope
   unless separately approved. Preserve callback bodies, paths and status codes.
3. Quiesce old bot/background/payment writers. Take fresh logical dumps including
   accounts, roles, databases and indexes; back up target data before replacing it.
4. Restore application namespaces/indexes first (`--nsExclude='admin.*'`), then admin
   accounts separately (`--nsInclude='admin.*' --numParallelCollections=1`); restoring
   accounts mid-import can invalidate authentication. Verify counts, indexes and access,
   refresh the backup and run `restic-roundy check --read-data`.
5. Activate Countly deliberately. With the old poller stopped and approval confirmed,
   create the production marker, unpause Starflake and explicitly start reconciliation.
   Never run both production pollers together.
6. Verify Telegram, media, payments/credit granting, callbacks, Countly and load/headroom.
   Keep old services recoverable and callback forwarding until outstanding payments settle.
   Rollback must stop the new poller and account for new writes; binary rollback is not data rollback.

## Privacy

Unlock git-crypt before evaluation. Inventory and private task notes stay git-crypt
protected; passwords/tokens stay in agenix, never Nix expressions or the store.
Encryption does not erase Git history or hide public DNS. Verify staged ciphertext
when changing attribute rules.
