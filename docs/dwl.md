# DWL desktop

An independent **DWL (UWSM)** session is enabled alongside Hyprland on
`interplanetary`; Hyprland remains available. No window picker, clickable
window previews, recursive groups, privacy/redaction, or application-specific
window policies are included.

## Ownership

- `packages/dwl/`: pinned DWL v0.9 (`98bea2c`), wlroots 0.20, XWayland,
  upstream IPC v2, then the local desktop patch, then `better-resize.patch`. Window/layout/input policy lives
  in feature headers, including compositor-owned Cairo/Pango group tabs, not
  a daemon or plugin framework.
- `home/config/noctalia-dwl/`: native Noctalia v5 shell defaults, installed as
  `~/.config/noctalia/config.toml` after native schema validation. Noctalia owns
  the exclusive 52px left sidebar, notifications, audio,
  wallpaper, polkit agent, lockscreen, and idle policy.
- `modules/wms/dwl.nix` and `home/modules/wms/wayland/dwl.nix`: UWSM,
  session-scoped services, portals, and monitor configuration.

Wallpaper remains `~/Pictures/wallpapers/03779_vyoletznebula_3840x2160.jpg`;
Noctalia browses `~/Pictures/wallpapers`. The shell uses the dark Rosé Pine
palette with 24px tray icons in the narrower sidebar. Kanshi configures `DP-1`
at 2560×1440, 180 Hz, scale 1. GTK handles file selection; the wlr portal handles
screenshots/screencasts. Its tofi monitor/window chooser remains independent
of the Noctalia launcher and uses an absolute executable path.

## Window behavior

`Super+B` toggles tabbed grouping for the current workspace. One or two flat
panes contain ordered tabs, with one visible member per pane. `Shift+H/L`
reorders tabs, crosses an inward edge into the neighbor, or splits out a second
pane at an outer edge when only one pane exists. Empty panes collapse; divider
ratios survive. `Super+U/C` chooses side-by-side/top-bottom. Each pane has a
26px title strip with clickable, ellipsized tabs. `H/L` cycles tabs in horizontal
strip order and `J/K` focuses panes, independent of pane orientation.
Floating/overlay selections use visible-window focus order, and outward pane
focus can leave for floating windows.

`Super+X` opens/hides an independent floating overlay. `Super+Shift+X` changes
membership; returning a member uses the current underlying workspace. Sending
an overlay member with `Super+1…0` also removes it from the overlay, placing it
on the selected ordinary workspace without changing its floating geometry. Overlay
toggles never retag, disconnect, resize, or retile clients. Transient dialogs
inherit membership and preserve the underlying fullscreen state. Ordinary
workspaces can change beneath the open overlay. The original removal of a tiled member
necessarily lets its former neighbors retile. Monitor removal or changed output
dimensions may require geometry adjustment.

`Super+Shift+V` maximizes to the work area; `Super+V` retains real application
fullscreen. Both restore prior floating geometry. New floating windows center
once at first map, relative to their parent when transient, not on subsequent
overlay/workspace changes. Explicit float/tile toggles and mouse dragging clear
maximization first; returning to a grouped tile selects that window's tab.
`Super+Shift+Space` remembers each window's last floating dimensions, including
manual resizing, and restores them when floating again. Tiled/maximized sizes
never replace this memory; toggling does not reset position.
`Super+right-drag` resizes from the nearest corner selected by the pointer's
starting quadrant, without teleporting the cursor. `Super+left-drag` moves.
Ordinary floating windows can extend beyond output edges, retaining one visible
pixel instead of jumping back by their whole size. US/RU keyboard layout is
remembered per window using public XKB APIs.

See [compositor controls](../packages/dwl/README.md) and
[widget configuration](../home/config/noctalia-dwl/README.md) for the complete list.
There is deliberately **no Super+Tab**.

## Session policy

UWSM owns environment publication, startup, and teardown. The DWL desktop entry
runs `dwl -s "uwsm finalize"`. `dwl-noctalia.service`, Kitty, and Kanshi are
conditioned on `XDG_CURRENT_DESKTOP=dwl` and stop with the graphical session.
Caelestia remains Hyprland-only; shared cliphist services skip DWL because
Vicinae owns its clipboard; Sway’s shared cliphist configuration is unchanged. No Eww/helper or companion shell daemons are
installed or launched by the DWL module. Noctalia app launches use
`uwsm-app -- $CMD`; logout runs `uwsm stop`.

`Super+P/O/semicolon` and the sidebar launcher left click run `vicinae toggle`.
`Super+Shift+P` opens Vicinae Run; `Super+Z` and the sidebar clipboard button
open Vicinae clipboard history. Vicinae owns app/run/clipboard pickers and
records history natively; Noctalia’s history retention is disabled while its
basic copy/paste transport stays active.
Native `noctalia msg` IPC handles the other shell shortcuts; workspaces use the existing
`zdwl_ipc_manager_v2` compositor protocol without a custom bridge.
GUI overrides in `~/.local/state/noctalia/settings.toml` win over the declarative
config; remove the relevant overrides to restore repository defaults.

`dwl-kitty.service` starts a hidden Kitty instance with the session. Super+Return
and Alt+Return create tiled/floating OS windows in its `dwl` instance group;
rendering/GPU caches are shared, but each terminal has its own shell/PTY.
The hidden instance keeps running after its last visible window closes and
stops with the desktop. Hyprland's Kitty launches are unchanged.

Idle defaults are lock at 600 s, displays off at 800 s, and
suspend-then-hibernate at 1200 s, with lock before sleep and displays restored
after resume. These replace neither Caelestia's Hyprland idle policy nor its
unresolved timeout-unit question.

## Deployment and verification

Build/review the `interplanetary` Home Manager configuration and compositor
without activating a running session. After deployment, log out and select
**DWL (UWSM)** in SDDM to load compiled shortcuts. Hyprland remains available.
Noctalia uses the existing PAM `login` service and its native logind
lock-before-suspend inhibitor. Audio overdrive retains the 150% ceiling.

Home Manager substitutes the absolute storage-key path and validates the TOML.
The service provisions a private runtime key once, preserving it across restarts
to retain access to old encrypted Noctalia clipboard history without a Secret
Service daemon. That history and its master key are preserved, not imported
into Vicinae.
The compositor boundary and transition harnesses remain relevant to window
policy: the transition tests query focused titles directly through a test-only
native Wayland IPC probe. The Rust bridge, DWL Eww config, and Eww-specific
hover/lock fixtures are removed. `packages/dwl/tests/noctalia.py` exercises compiled shell shortcuts,
Vicinae command routing through a disposable stub (not actual Vicinae rendering),
native panels, restart/reconnect, notification
ownership, workspace IPC, rendering, and native lock lifetime in disposable
headless DWL/DBus sessions. PAM unlock, physical inputs, suspend/resume, real
audio devices, and session startup/logout still require desktop testing.

The required shared ast-grep scan has previously crashed with exit 139
(`dotfiles-q7v1`); no rules or paths were suppressed.
