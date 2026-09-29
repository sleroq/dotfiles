# ru-relay deployment

Do not build on ru-relay: its ~1 GB of RAM is insufficient for the Broadcast Box frontend build and the host can become unresponsive. Build the **ru-relay system closure** on cumserver, copy it, then activate the prebuilt closure on ru-relay. Do not run `nixos-rebuild switch --flake` on ru-relay: it can start another local build.

From a local machine, connect with SSH agent forwarding (`ssh -A cumserver`). On cumserver, use a clean, synced copy of this flake containing the intended changes and lock file; do not accidentally deploy unrelated dirty changes. The key authorized for ru-relay is listed in `hosts/ru-relay/default.nix`. For example, if that key is loaded in the forwarded agent:

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
