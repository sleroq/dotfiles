# Roundy

- Existing VPS: `ssh roundy`, x86_64 Linux.
- Deploy with `nixos-rebuild --build-host cumserver --target-host roundy`
  (`--no-reexec` on Darwin). Never build on Roundy; `max-jobs = 0` and empty builders
  deliberately prevent target-side builds.
- No production cutover or starting the production poller is authorized.
  Application, database, secrets, monitoring integration and deployment are
  owned by the parent task; this host baseline does not start production apps.
- Preserve `system.stateVersion = "25.11"` across nixpkgs upgrades.
- Root disk uses `virtio_scsi`. Keep it in the initrd and run `check-initrd.sh`
  against the actual built artifact on cumserver before boot-critical changes.
  Keep the original working 25.11 generation until the new boot is verified.
- Preserve the root console password and SSH host keys. Do not add password
  material to the repository or enable cloud-init after provider initialization.
- Preserve the native provider Zabbix agent; do not run the Timeweb installer
  or add another monitoring stack. Provider access to port 10050 is restricted
  to its three configured addresses; metrics access is restricted to
  `cumserverAddress` in encrypted `secrets/default.nix`.
- GC is manual. Keep rollback generations; do not perform broad deletion
  without approval.
- Keep inventory metadata in encrypted `secrets/default.nix`; do not copy it
  into plaintext documentation or task notes.
