# Scoped DWL desktop

Applies to upstream **v0.9, revision 98bea2c**, with wlroots **0.20** and
XWayland. Apply `patches/ipc.patch`, then `patches/desktop.patch`, and copy
`config.h` into the source. The Nix expression owns source selection and session
entry installation; these patches do not change the pin or IPC XML.

`ipc.patch` is the upstream v0.9 IPC adapter with duplicate manager-global
registration removed. `desktop.patch` keeps event/scene hooks in `dwl.c` and
implements policy in `workspaces.h`, `window-state.h`, and `input-layout.h`,
with pane decoration in `group-tabs.h`.
Inactive tabs stay in the client list and workspace counts, but are absent from
scene traversal, pointer hit testing, and focus enumeration. Overlay members
are independent of tags and excluded from ordinary workspace counts.

## Controls

All shortcuts below use Super unless otherwise specified.

- `Q W E R T A S D F G`: workspaces 1–10; `1 … 0`: send selected window.
- `B`: toggle flat tabbed panes; `U` / `C`: side-by-side / top-bottom.
- `H/L`, Left/Right: previous/next tab in title-strip order, with wraparound.
  `J/K`, Down/Up: next/previous pane, regardless of pane orientation.
  Floating/overlay selections and ordinary layouts use upstream visible focus order.
- `Shift+H/L`: reorder tabs; crossing an edge moves to the other pane,
  creating a singleton on the requested side if only one pane exists. With two
  panes, inward edges move into the neighbor; outward edges do nothing. Empty
  panes collapse; never more than two.
- `Ctrl+H/L`, Super+scroll: divider ratio; `Shift+A`: toggle group-move
  selection for the next number shortcut. Super+Shift+scroll steps workspaces
  with wraparound.
- `X`: show/hide the floating overlay; `Shift+X`: send/return selected window.
  Membership changes do not retag on entry. Return uses the current workspace.
  Show/hide preserves rectangles and stacking and restores remembered focus.
- `Shift+V`: work-area maximize; `V`: native fullscreen; `Shift+Space`: float;
  `Ctrl+Y`: sticky; `Shift+C`: close. Super+F8 toggles focus-following.
- Super+Return: Kitty; Alt+Return: floating Kitty. Both open OS windows in the
  same `dwl` Kitty instance, started hidden with the DWL session.
- `P` / `O` / semicolon: apps; `Shift+P`: run; `Z`: clipboard; `Y`: Nemo.
- Ctrl+Alt+L: lock; `Shift+N`: notification panel.
- Print: Flameshot GUI; Shift+Print: full screenshot saved/copied;
  Super+Print: share screenshot. AudioMute, AudioMicMute, Calculator, and Super+M toggle the microphone;
  brightness, volume, and player media keys are bound.

Keyboard layout is US/RU, Left Ctrl+Left Super switches, Caps acts as Ctrl. Each window
remembers its layout using public XKB APIs; physical/virtual keyboard states
and their wlroots groups are restored on focus. There are no application
policies except the explicit `dwl-floating-terminal` identity passed by the
Alt+Return command. Long-lived launchers use `uwsm-app` where appropriate.

Ordinary tile/monocle/floating layouts remain available through native IPC.
Group mode is off by default and opt-in per workspace; the floating layout shows all ordinary
clients instead of hiding tabs. Divider ratios survive pane collapse. Ordinary tiled/monocle and pane layouts
use 4px inner gaps and 8px horizontal/4px vertical outer gaps; floating, overlay,
maximized, and native fullscreen rectangles are not inset. New floating clients
center once on first map: in the work area, or relative to their transient parent,
before saving a pre-map maximize restore rectangle. Existing clients are never
recentered. Transient dialogs inherit overlay membership and do not cancel an
underlying fullscreen client.
Pointer hit-testing uses the new position after movement, so edge entry and
leave are delivered on the same event rather than one motion late.
Grouped arranged panes reserve a compositor-owned 26px Cairo/Pango title row,
including singleton panes. Titles are UTF-8 ellipsized; clicks select only the displayed
pane’s tabs and respect topmost scene nodes. Floating, overlay, maximized and fullscreen
windows do not reserve a title row. Explicit float/move operations unmaximize first;
returning to tile selects that window’s tab. `Shift+Space` remembers each window's
last floating dimensions and restores them when floating again, without resetting
its position. The first floating size is seeded before initial tiling/maximization.
Interactive resizing updates the next remembered size; maximization does not overwrite it.
Ordinary floating bounds retain a single
visible pixel rather than snapping entirely offscreen windows across their width.
No window-picker protocol, daemon C, capture redaction, or application privacy
rules are introduced.

## Verification

Local dependencies (no system activation):

```sh
nix-shell -p wlroots_0_20 wayland wayland-scanner wayland-protocols \
  libinput libxkbcommon pixman libdrm libxcb libxcb-wm cairo pango pkg-config gcc gnumake
make XWAYLAND=-DXWAYLAND XLIBS='xcb xcb-icccm'
/path/to/packages/dwl/tests/run.sh "$PWD"
```

The test compiles the actual patched compositor into a boundary harness and
checks inactive-tab visibility, retained enumeration/tags, independent overlay
visibility overriding sticky, workspace changes beneath an overlay, empty-pane
collapse with stable ratio, saved-pointer cleanup, directional splitting/crossing/collapse, exact gap
geometry, unique keybindings, initial maximize requests before surface initialization,
first-map floating placement/maximize restore, and real XKB layout restore.
It never opens a backend or graphical session.

`tests/hover.py` independently starts a headless compositor, helper, and Eww;
three complete hover cycles exercise first-motion entry/exit and sensor-to-drawer
handoff. A GTK fixture checks initial native maximization, repeated normal-size
restoration, transient overlay visibility/focus, and underlying fullscreen preservation. It uses a temporary runtime/config directory and
disables audio access. With the built compositor/helper on PATH:

```sh
nix-shell -p python3 eww playerctl wlrctl wtype gtk3 pkg-config gcc \
  --command 'python3 packages/dwl/tests/hover.py'
```

`tests/lock.py` clicks the actual sidebar lock button in a disposable headless
session, including a 300ms startup delay. It checks daemon survival past the
widget deadline, fail-closed gray rendering after locker death, and compositor
SIGTERM shutdown while locked. It never authenticates or touches the active
session; normal PAM unlock and physical logout are not covered.

```sh
nix-shell -p wlrctl --run 'python3 packages/dwl/tests/lock.py'
```

Parent runtime verification also covered real Wayland/XWayland clients, pane
layouts, overlay geometry/focus, native fullscreen/work-area maximize, wallpaper,
and isolated audio-stream controls. Physical monitors/input, portals, and session
startup/logout still need final desktop quality testing.

`tests/transitions.py` adds an isolated real GTK/native-state regression for explicit
unmaximize/retile, grouped floating focus fallback, hidden-tab H/L and pane J/K in both orientations,
strip reservation, title click selection (including a rounded three-tab boundary),
application clicks, and an oversized floating drag stable across commits/release.
`tests/drag.c` is a dedicated held-button virtual-pointer fixture; its protocol XML
comes from swaywm/wlr-protocols (MIT license included in the file).

```sh
nix-shell -p python3 wlrctl wtype gtk3 pkg-config gcc grim wayland wayland-scanner \
  --run 'dbus-run-session -- python3 packages/dwl/tests/transitions.py'
```
