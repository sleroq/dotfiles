# ru-relay deployment

Never build here; follow root builder selection and prefer `nixos-rebuild` with
an explicit `--build-host` and `--target-host`.

- Only 1 GiB RAM: check memory/swap, serialize transfers/imports, and pause under
  pressure. Never overlap cache copies with another closure transfer.
- Build the intended flake/lock on the selected Linux builder. Use the target's
  authorized SSH identity (see `default.nix`), forwarding the agent if needed.
- Review `nixos-rebuild dry-activate`, then use `nixos-rebuild switch` with the
  same checkout and lock. Configure the `ru-relay` SSH alias privately. From
  Darwin, use `--no-reexec`, for example:

  ```sh
  nixos-rebuild dry-activate --flake .#ru-relay --build-host desktop \
    --target-host root@ru-relay --no-reexec
  nixos-rebuild switch --flake .#ru-relay --build-host desktop \
    --target-host root@ru-relay --no-reexec
  ```

- Reserve manual `nix copy`, profile updates, and activation for a demonstrated
  tool limitation, not the default deployment path.
- Verify `/run/current-system`, affected services and a real public client connection.
