# Host access

- Remote access to `div`, `interplanetary` (`desktop`), and `portable` requires Tailscale. If connection fails, first check Tailscale is running; if not, stop and ask the user. Then check the selected Tailscale network: `a9d4` for `div`, `6678` for `portable`/`desktop`. Switching networks to complete the task is allowed.

# Build host selection

- `portable` is Darwin/macOS. Never build Linux systems on Darwin; use a Linux build host.
- Never build on `ru-relay` or `warsaw` (swarsaw): too little RAM/CPU. Build their systems locally on a capable Linux host; from `portable`, use `interplanetary` if reachable over SSH, otherwise `cumserver`.
- Build `cumserver` on itself by default. Offload large uncached builds (e.g. Rust/C++) to `interplanetary`, then copy the finished outputs to `cumserver`.
- Build `interplanetary` only on itself.
- Build `div` on itself by default; this is allowed and preferred, including when deploying from `portable`. Do not default to `interplanetary` or `cumserver` for `div` builds.
- For other Linux systems, build locally on a capable Linux host; from `portable`, use a capable Linux server.
- Distinguish build and deployment host options: `--build-host` selects the builder, `--target-host` selects the deployment target. They may be the same host (preferred for `div`). Copy and activate prebuilt closures on weak hosts (`ru-relay` and `warsaw`); do not trigger target-side builds there.

# Paseo schedules

- For these dotfiles hosts, ALWAYS create/edit/remove schedule definitions in `services.paseo.schedules` in host Nix configuration and associated prompt files, never through the GUI/CLI/MCP. Read the current repository: Nix is authoritative even before deployment; do not overwrite it from runtime state.
- Pause/resume, run-now, and log inspection are allowed operational actions. The reconciler leaves unmanaged existing schedules untouched, but declare all new schedules in Nix. Adoption via `adoptId` preserves the stable schedule ID and run history. Heartbeats remain outside Nix schedule ownership.
