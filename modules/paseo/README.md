# Declarative schedules

NixOS daemons managed by `modules/paseo.nix` accept
`services.paseo.schedules`. For example:

```nix
services.paseo.schedules.daily-review = {
  name = "Daily review";
  cron = "0 9 * * *";
  timezone = "Europe/Berlin";
  provider = "pi";
  model = "openai/gpt-6.1-sol";
  thinkingOptionId = "low";
  cwd = "/home/paseo/projects/dotfiles";
  prompt = builtins.readFile ./daily-review.md;
};
```

Div's declarations live in `hosts/div/paseo-schedules.nix`, with its stack-update
prompt in `hosts/div/paseo-stack-update.md`. Edit those files, not the live
schedule definition. The repository is authoritative even when a change has not
been deployed yet; runtime inspection is not a reason to replace newer Nix
settings with deployed values. Prompts and settings enter the public Nix store:
never put secrets in them.

## Lifecycle and app controls

`paseo-schedules.service` runs as the dedicated Paseo user after the daemon is
available. It reconciles on daemon startup/restart and on deployment when its
script, package, or desired definitions change. It does not poll or continually
undo app edits.

- **Nix owns definitions:** name, prompt, cron/timezone, provider/model/mode,
  thinking, working directory, archive behavior, isolation, run limit, and expiry.
  App edits to these fields are restored at the next reconciliation.
- **The app owns operations:** pause/resume, run-now, and run logs remain available.
  Reconciliation never resumes a paused schedule or fires a newly created one.
  Completed schedules are not automatically resumed either.
- **Only explicitly managed schedules are touched.** App-created schedules and
  heartbeats are left alone. Agents should nevertheless declare new recurring
  schedules in Nix; heartbeats are separate.
- Removing a declaration deletes its owned schedule on the next deployment,
  including its Paseo history. Deleting a managed schedule in the app instead
  causes recreation at reconciliation, without the deleted history.

Attribute names such as `daily-review` are stable ownership keys. Changing the
display `name` updates the same schedule; changing the attribute key creates a
new schedule and deletes the old one. Ownership IDs are recorded in
`/var/lib/paseo-schedules/managed.json`. Keep that file with daemon state when
migrating or restoring the host; it is runtime bookkeeping, not a second source
of configuration.

To import an existing schedule, set `adoptId` to its exact ID from read-only
inspection. Its existing ID, run history, and pause state are preserved. Once
ownership is recorded, the registry tracks the actual ID, including after
recreation; `adoptId` is only the initial adoption hint. If the hinted schedule
no longer exists, a new one is created.

## Implementation and checks

The reconciler uses Paseo's schedule RPCs, never edits its schedule storage, and
patches only changed fields so unrelated edits do not reset the next cron run.
The current public SDK facade and schedule CLI cannot update all needed fields.
`schedules.mjs` therefore reuses the **pinned package's internal CLI connection
helper** and underlying schedule client. This boundary is version-coupled:
check it when bumping Paseo, particularly
`lib/paseo/packages/cli/dist/utils/client.js` and the schedule RPC schemas.

Run focused tests with:

```bash
node --test modules/paseo/schedules.test.mjs
```

A failed reconciliation is reported through systemd and retried; it does not
prevent the main daemon from remaining available. Even an empty schedule set
keeps the reconciliation service so removing the last declaration is applied.
