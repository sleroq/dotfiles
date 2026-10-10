# Native DWL shell

Noctalia v5.2.1 owns the fixed exclusive 52px left sidebar, notifications, media/audio, polkit, wallpaper, lockscreen and idle.
Workspaces use native `zdwl_ipc_manager_v2`; no helper is required.
Home Manager validates this TOML before installing `~/.config/noctalia/config.toml`.
The dark Rosé Pine palette uses `#191724` surfaces and `#e0def4` text, matching
the Rosé Pine editor theme. Tray icons retain 24px allocations (1.5× the default),
while a one-line native patch keeps tray menus at the normal shell UI scale.
Five Tela status glyphs (Blueman normal/active/disabled and Gammastep on/off)
use padding-corrected SVG viewBoxes, preserving their aspect ratios, colors
and states. These local overrides leave the rest of the installed Tela theme intact.
Cards, buttons, inputs and menus use Noctalia's built-in borderless settings;
outer panel outlines and input focus rings remain. `Rose-Pine-Flat.json` keeps
the built-in dark Rosé Pine colors except for `mSurfaceVariant`, which matches
`mSurface` so nested cards blend into their panels. Calendar layout and padding
remain unchanged.

`Super+P/O/semicolon` and the sidebar launcher left click run `vicinae toggle`; `Super+Shift+P` opens Vicinae Run;
`Super+Z` and the sidebar clipboard button open Vicinae clipboard history.
Vicinae owns app/run/clipboard pickers and records clipboard history natively;
Noctalia’s history retention is disabled; its basic copy/paste transport stays active. Ctrl+Alt+L locks;
`Super+Shift+N` opens control-center notifications. Microphone shortcuts
intentionally mute the microphone, including AudioMute. Native shell IPC uses `noctalia msg`.
Logout runs `uwsm stop`; Kitty and Kanshi remain session-scoped.

Wallpaper defaults to `~/Pictures/wallpapers/03779_vyoletznebula_3840x2160.jpg`;
Kanshi retains DP-1 2560×1440 at 180 Hz. Native idle actions lock at 600s,
turn screens off at 800s, and run `systemctl suspend-then-hibernate` at 1200s.
Native lock-before-suspend uses the logind inhibitor and existing PAM `login`.
GUI overrides in `~/.local/state/noctalia/settings.toml` take precedence;
remove relevant overrides to restore declarative defaults.

## Retained legacy clipboard storage

Old Noctalia encrypted clipboard history and its master key are retained, not
imported into Vicinae. This host has no Secret Service. `dwl-noctalia.service` provisions a random
64-character lowercase hex master key at `$XDG_STATE_HOME/noctalia/storage.key`
(default `~/.local/state/noctalia/storage.key`) before starting Noctalia.
The file is user-private and generated at runtime, never stored in Nix.
Existing keys are preserved: replacing one loses access to encrypted history.
No Secret Service daemon is needed. Home Manager substitutes `@storageKey@`
with the absolute state path and validates the resulting TOML.

For standalone validation, substitute `@storageKey@` with an absolute path in
a temporary copy, then run `noctalia config validate` on that copy.
The old DWL Eww configuration, Rust bridge, and Eww-only fixtures are removed.
Compositor transition tests query native Wayland IPC directly.
