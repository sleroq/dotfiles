# ru-relay deployment

Never build on ru-relay. Select a builder using the root `AGENTS.md`, copy the system closure, then activate it here. Do not run `nixos-rebuild switch --flake` without a remote build host: it can start a local build.

On the selected Linux builder (use `ssh -A <builder>` for SSH agent forwarding), use a clean, synced copy of this flake containing the intended changes and lock file; do not accidentally deploy unrelated dirty changes. The key authorized for ru-relay is listed in `hosts/ru-relay/default.nix`. For example, if that key is loaded in the forwarded agent:

```sh
cd /path/to/synced/dotfiles
system=$(nix build --no-link --print-out-paths .#nixosConfigurations.ru-relay.config.system.build.toplevel)
pub=$(mktemp)
ssh-add -L | grep 'cantundo@pm.me warsaw' > "$pub"
export NIX_SSHOPTS="-o BatchMode=yes -o IdentitiesOnly=yes -i $pub"
nix copy --no-check-sigs --to ssh-ng://root@ip "$system"
ssh -o BatchMode=yes -o IdentitiesOnly=yes -i "$pub" root@ip "$system/bin/switch-to-configuration dry-activate"
# Review the units affected by dry-activate before switching:
ssh -o BatchMode=yes -o IdentitiesOnly=yes -i "$pub" root@ip "nix-env -p /nix/var/nix/profiles/system --set '$system' && '$system/bin/switch-to-configuration' switch"
rm -f "$pub"
```

`--no-check-sigs` is needed when copying locally built, unsigned paths; use it only for a builder you trust. Verify `/run/current-system`, the affected systemd services, and the public endpoint after switching.
