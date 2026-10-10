# DWL desktop

An independent **DWL (UWSM)** session is enabled alongside Hyprland on
`interplanetary`; Hyprland remains available. No window picker, clickable
window previews, recursive groups, privacy/redaction, or application-specific
window policies are included.

## Ownership

- `packages/dwl/`: pinned DWL v0.9 (`98bea2c`), wlroots 0.20, XWayland,
  upstream IPC v2, then a local desktop patch. Window/layout/input policy lives
  in feature headers, including compositor-owned Cairo/Pango group tabs, not
  a daemon or plugin framework.
- `packages/dwl-helper/`: Rust IPC/audio subscriptions, commands, and drawer
  hover coordination. Eww receives newline-delimited JSON through `deflisten`.
- `home/config/eww-dwl/`: fixed-width exclusive left sidebar, read-only window
  title, workspaces/tray/clock, and non-exclusive calendar/resource/media and
  audio drawers. Only the sidebar changes the compositor work area.
- `modules/wms/dwl.nix` and `home/modules/wms/wayland/dwl.nix`: UWSM readiness,
  session-scoped services, portals, launchers, wallpaper, lock/idle, and monitor
  configuration. Caelestia is restricted to Hyprland.

`awww` is the current upstream/Nixpkgs name for swww. Wallpaper remains
`~/Pictures/wallpapers/03779_vyoletznebula_3840x2160.jpg`. Kanshi configures
`DP-1` at 2560×1440, 180 Hz, scale 1. GTK handles file selection; the wlr portal
handles screenshots/screencasts in DWL without replacing Hyprland's portal.
Its monitor/window chooser uses tofi's dmenu mode with an absolute executable
path: the portal service's restricted PATH cannot find the desktop's launchers.

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
membership; returning a member uses the current underlying workspace. Overlay
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
Ordinary floating windows can extend beyond output edges, retaining one visible
pixel instead of jumping back by their whole size. US/RU keyboard layout is
remembered per window using public XKB APIs.

See [compositor controls](../packages/dwl/README.md) and
[widget configuration](../home/config/eww-dwl/README.md) for the complete list.
There is deliberately **no Super+Tab**.

## Session policy

UWSM owns environment publication, startup, and teardown. The DWL desktop entry
runs `dwl -s "uwsm finalize"`; Eww/helper/wallpaper/notification/idle services
are conditioned on `XDG_CURRENT_DESKTOP=dwl`. Long-lived launches use
`uwsm-app`; short volume, screenshot, and helper commands do not.

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

The configuration is registered in the system profile and persistently activated
with `switch-to-configuration switch`. The initial EFI-space failure was resolved
by deleting 27 older system generations and refreshing boot entries, retaining
the booted generation, the pre-DWL rollback, and the current deployment.
Activation does not replace the running compositor. Log out and select
**DWL (UWSM)** in SDDM to load updated compositor code and compiled shortcuts;
Hyprland remains available. `uwsm stop` ends the current DWL session.

Build the desktop packages or the `interplanetary` system normally; do not build
server derivations locally. The compositor's boundary harness and Rust socket
checks cover visibility, pane membership/cleanup, geometry, XKB restoration,
readiness, abandoned sockets, shutdown, and hover handoff ordering.

Isolated headless runtime tests exercise real clients, IPC workspace changes,
overlay rectangle/focus preservation, distinct maximize/fullscreen, Eww drawer
hover, wallpaper, and per-application audio volume/mute/routing. They do not
replace final physical-monitor/input/session testing. The screencast portal was
also tested in the physical DWL session: tofi selection, session creation, and
PipeWire remote access delivered five video buffers each for DP-1 (2560×1440)
and a dedicated Kitty fixture window, without saving images or recordings.

For helper development, include PulseAudio in the runtime library search path:

```sh
cd packages/dwl-helper
nix-shell -p pkg-config libpulseaudio cargo-machete --run '
  export LD_LIBRARY_PATH=$(pkg-config --variable=libdir libpulse)
  cargo test && cargo clippy --workspace --all-targets --all-features -- -D warnings && cargo machete
'
```

The required shared ast-grep scan currently crashes with exit 139 before
reporting findings, including outside the repository with the shared config.
Tracked as `dotfiles-q7v1`; no rules or paths were suppressed.
