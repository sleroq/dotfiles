# Flake inputs

Keep exact commit revisions in `flake.lock`, not in `flake.nix` URLs. Use
upstream URLs without commit pins (for example, `github:earendil-works/pi`).
Release tags and explicit branch refs are allowed when they select the intended
update track instead of following the default branch. Local directory inputs
are also allowed; `flake.lock` still owns exact revisions for remote inputs.

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
| `ru-relay`, `warsaw` | capable Linux host; from Darwin prefer `interplanetary`, otherwise `cumserver` |
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

## Agent jobs

Manage jobs through `services.agent-jobs` in `hosts/div/agent-jobs.nix` and its
host-owned prompt files. Keep job timers disabled until explicitly approved.
Paseo is for interactive agents, not recurring jobs.
