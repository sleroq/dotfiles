# ru-relay deployment

Never build here; follow root builder selection and use a prebuilt system closure.

- Only 1 GiB RAM: check memory/swap, serialize transfers/imports, and pause under
  pressure. Never overlap cache copies with another closure transfer.
- Build the intended flake/lock on the selected Linux builder. Use the target's
  authorized SSH identity (see `default.nix`), forwarding the agent if needed.
- Copy the closure with `nix copy`. Use `--no-check-sigs` only for unsigned outputs
  from a trusted builder. Dry-activate its exact `switch-to-configuration` path.
- After review, set `/nix/var/nix/profiles/system` to that exact store path with
  `nix-env -p ... --set`, then run its `switch-to-configuration switch`.
  Verify `/run/current-system`, affected services and a real public client connection.
