# Legacy DWL Eww widgets

Retained fixtures only: not installed or launched by the active DWL session.
The active shell is [native Noctalia v5](../noctalia-dwl/README.md).
Hover/lock tests below validate legacy Eww/helper behavior, not Noctalia.

Requires Eww with Wayland support, `dwl-helper` (running daemon), `playerctl`,
`swaylock`, and `swaync-client` on the session PATH.

```sh
export DWL_EWW_CONFIG="$HOME/.config/eww-dwl"
eww --config "$DWL_EWW_CONFIG" --force-wayland daemon
eww --config "$DWL_EWW_CONFIG" open-many sidebar top-sensor audio-sensor
```

The helper opens/closes `top-drawer` and `audio-drawer`. Sensors pass
`--source sensor`; content uses the default source. Independent source tracking
keeps a late sensor-leave command from closing hovered content. The helper
provides 180ms crossing grace.
Only the fixed 74px sidebar reserves space; clock changes cannot resize it.
Sensors are 3px edge strips, not overlays.
Monitor matching is `DP-1`, then nested `WL-1`, then index 0. To select another
output, replace the identical `:monitor` JSON matchers in `eww.yuck`.

The initial snapshot is the complete helper schema with ten workspaces and
null audio defaults. Audio devices/streams and temperatures are native Eww
`for` lists; labels are data, never generated Yuck. Audio sliders allow 0–150%.
Eww's range widget suppresses `onchange` for programmatic value updates and
ignores incoming values while dragging; no extra debounce script is used.
Device buttons select defaults; buttons beneath each stream route its output.

The `Lock` button runs `swaylock -f`, with a 10-second startup deadline instead
of Eww's 200ms default. Once locking completes, the launcher exits while the
locker stays alive until authentication. This is lock, not logout; use `uwsm stop`
for logout. Do not run a foreground locker under a timed widget callback: killing
it can leave the compositor deliberately fail-closed on a gray background.

The isolated headless regression in `packages/dwl/tests/hover.py` starts its
own compositor/helper/Eww instance without touching the current desktop or
audio. See `packages/dwl/README.md` for its command. For manual debugging, set
`WAYLAND_DISPLAY` to the test compositor's socket before starting this config.

Stop only this instance with `eww --config "$DWL_EWW_CONFIG" kill`.
Missing helper/player errors are reported in that instance's `eww logs`.
