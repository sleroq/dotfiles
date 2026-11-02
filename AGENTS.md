# Documentation privacy

Keep VM IP addresses out of `AGENTS.md` and all other documentation. Use
hostnames or SSH aliases instead; configure address mappings privately.

# Deployments

Read the target's `AGENTS.md` before deploying. Use the current checkout and
`nixos-rebuild <action> --flake .#<target> --build-host <builder> --target-host <target>`
(`--no-reexec` on Darwin). Prefer this over manual staging/activation except for
the weak-host prebuilt-closure workflow or a demonstrated tool limitation.

| Target | Builder |
| --- | --- |
| `div` | `div` |
| `interplanetary` (`desktop`) | itself only |
| `cumserver` | itself; offload large uncached builds to `interplanetary` |
| `ru-relay`, `warsaw` (`swarsaw`) | capable Linux host; from Darwin prefer `interplanetary`, otherwise `cumserver` |
| `roundy` | `cumserver` |

Never build Linux on `portable` (Darwin), or build on `ru-relay`/`warsaw`/`roundy`.
Other Linux targets need a capable Linux builder. Copy and activate prebuilt
closures on `ru-relay`/`warsaw`.

- Keep deployments scoped; do not activate unrelated dirty changes. Review
  dry activation, then verify affected services and effective runtime versions.
- System, standalone Home Manager (`dev@cumserver`), and Starflake releases are
  separate deployments. See [Starflake operations](hosts/cumserver/modules/STARFLAKE.md).
- Keep large builds off production when they exceed its resources; never
  throttle administrative SSH. Use scoped diagnostics, not broad argv/env dumps.

## Access

`div`, `interplanetary`, and `portable` require Tailscale. On connection failure,
check it is running; if stopped, ask the user. Select `a9d4` for `div`, `6678` for
`desktop`/`portable`. Switching is allowed, but coordinate with other deployment
sessions: the laptop's selected network is shared.

## Paseo schedules

Manage definitions through `services.paseo.schedules` and prompt files in host Nix,
never GUI/CLI/MCP. Div uses `hosts/div/paseo-schedules.nix`. Repository state wins
over runtime state, including undeployed changes. Use `adoptId` to retain an
existing schedule's ID/history; the reconciler leaves unmanaged schedules alone.
Pause/resume, run-now, and log inspection are allowed. Heartbeats are outside Nix ownership.
