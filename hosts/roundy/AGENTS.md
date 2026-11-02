# Roundy

- `ssh roundy`; build on `cumserver`, never the target. Follow root deployment rules.
- No production cutover or poller startup without separate owner approval.
  See [runbook](README.md) for the rehearsal gate and cutover checklist.
- Preserve `system.stateVersion = "25.11"`, root console password and SSH host keys.
  Do not enable cloud-init or run provider installers.
- Keep `virtio_scsi` in the initrd. Run `check-initrd.sh` on the actual built artifact
  before boot-critical changes; retain a verified working rollback generation.
- Preserve provider Zabbix and its restricted access; do not add another monitoring stack.
- GC is manual; no broad deletion without approval.
- Keep inventory in encrypted `secrets/default.nix`, not plaintext docs/tasks.
