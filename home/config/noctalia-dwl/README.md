# Native DWL shell

Noctalia v5.2.1 owns the fixed exclusive 74px left sidebar, launcher,
clipboard, notifications, media/audio, polkit, wallpaper, lockscreen and idle.
Workspaces use native `zdwl_ipc_manager_v2`; no helper is required.
Home Manager validates this TOML before installing `~/.config/noctalia/config.toml`.

`Super+P/O/semicolon` opens apps; `Super+Shift+P` opens `/run`, a freeform
command provider using `uwsm-app -- {query}`. Interactive commands must launch
Kitty explicitly. `Super+Z` opens clipboard; Ctrl+Alt+L locks;
`Super+Shift+N` opens control-center notifications. Microphone shortcuts
intentionally mute the microphone, including AudioMute. IPC uses `noctalia msg`.
Logout runs `uwsm stop`; Kitty and Kanshi remain session-scoped.

Wallpaper defaults to `~/Pictures/wallpapers/03779_vyoletznebula_3840x2160.jpg`;
Kanshi retains DP-1 2560×1440 at 180 Hz. Native idle actions lock at 600s,
turn screens off at 800s, and run `systemctl suspend-then-hibernate` at 1200s.
Native lock-before-suspend uses the logind inhibitor and existing PAM `login`.
GUI overrides in `~/.local/state/noctalia/settings.toml` take precedence;
remove relevant overrides to restore declarative defaults.

## Clipboard persistence key

This host has no Secret Service. `dwl-noctalia.service` provisions a random
64-character lowercase hex master key at `$XDG_STATE_HOME/noctalia/storage.key`
(default `~/.local/state/noctalia/storage.key`) before starting Noctalia.
The file is user-private and generated at runtime, never stored in Nix.
Existing keys are preserved: replacing one loses access to encrypted history.
No Secret Service daemon is needed. Home Manager substitutes `@storageKey@`
with the absolute state path and validates the resulting TOML.

For standalone validation, substitute `@storageKey@` with an absolute path in
a temporary copy, then run `noctalia config validate` on that copy.
Legacy Eww/helper hover and lock fixtures do not validate this shell.
