# Warsaw deployment

Never build here; follow root builder selection and copy a prebuilt closure.

- Reinstall: use a small kexec image (24.11 fits), partition/mount with installer
  tools, then `nixos-anywhere --phases install --store-paths ...` directly to `/mnt`.
  The default disko closure exceeds installer tmpfs RAM; temporary disk swap may be
  needed. Verify disk by-id before partitioning.
- Preserve the SSH ed25519 host key via `--extra-files`: it is also the age identity.
- Keep nginx in `acme`; verify certificate renewal and nginx/tunnel reloads.
- RU primary 443 and reverse 2083 share the Warsaw-initiated FRP bridge: they are
  not independent fallbacks. RU 2080 uses cumserver instead. Verify cover traffic
  **and authenticated client traffic**; a local listener check is insufficient.
