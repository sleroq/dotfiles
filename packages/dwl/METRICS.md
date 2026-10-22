# DWL → Prometheus

`patches/metrics.patch` applies after `better-resize.patch` to the pinned DWL
v0.9/wlroots 0.20 desktop. It adds `metrics.h` and small lifecycle/input/geometry
hooks; no additional library, daemon dependency, network listener, or Wayland
protocol is added to the compositor. Export is **disabled by default**.

## Enable and scrape

Set these variables **in the compositor's environment before starting DWL**:

```sh
mkdir -m 700 -p "$XDG_RUNTIME_DIR/dwl-metrics"
export DWL_METRICS_FILE="$XDG_RUNTIME_DIR/dwl-metrics/session.prom"
# Optional; default is 60 seconds without compositor-delivered input:
export DWL_METRICS_IDLE_SECONDS=60
# Optional high-cardinality live-window series:
export DWL_METRICS_WINDOWS=1
# Optional sensitive metadata; neither is enabled by default:
export DWL_METRICS_EXECUTABLES=1
export DWL_METRICS_TITLES=1  # only effective together with WINDOWS=1
```

For the UWSM session these exports belong in `~/.config/uwsm/env-dwl`; ensure
the directory exists before the compositor starts (or create it in that file).
Restart the login session to load the newly built compositor and environment.
Setting variables in a terminal inside an already running DWL does not enable
its metrics. Use a unique destination per compositor instance.

Every second DWL publishes a complete Prometheus text snapshot via a temporary
file and same-directory rename. Files are **0600**, regardless of the umask.
The destination directory must already exist and be trusted. Use a local
runtime filesystem, not a network mount: publication is a small synchronous
write on the compositor event loop, not asynchronous I/O. Export failures are
logged on transition into failure and retried without stopping DWL.

A collector must run **as the same user** (or otherwise be explicitly authorized
to read the private file). For example, run node_exporter as a user service:

```sh
node_exporter \
  --web.listen-address=127.0.0.1:19100 \
  --collector.disable-defaults \
  --collector.textfile \
  --collector.textfile.directory="$XDG_RUNTIME_DIR/dwl-metrics"
```

Prometheus can scrape `127.0.0.1:19100` on that host. Prometheus on a different
host cannot reach this loopback address; relay through the existing Alloy
remote-write pipeline instead of opening a new firewall port.

### Existing interplanetary monitoring

`hosts/interplanetary/default.nix` already has Alloy remote-writing to
`https://cum.army/api/v1/write`. Its system service must **not** be assumed able
to read a user's 0600 textfiles. Keep the same-user collector above, then add
this separate scrape to Alloy's configuration if enabling collection:

```alloy
prometheus.scrape "dwl" {
  targets = [{
    "__address__" = "127.0.0.1:19100",
    "job" = "dwl",
    "instance" = "Interplanetary",
    "node_name" = "Interplanetary",
    "node_type" = "remote",
  }]
  scrape_interval = "15s"
  forward_to = [prometheus.remote_write.cumserver.receiver]
}
```

This PR wires the patch into the Nix package, but deliberately does **not**
activate collection, launch a collector, change the running session, or send
window/app metadata to remote storage. The commands/configuration above are
an explicit opt-in deployment recipe. Local loopback HTTP is not authentication;
other local users may be able to scrape that endpoint.

## Metric catalogue

All names below have the `dwl_` prefix. Counters reset on compositor restart.
Application counters survive window close until the compositor exits.

| Metric | Type / labels | Meaning |
| --- | --- | --- |
| `windows` | Gauge: `kind` | `all`, `fullscreen`, `special`, `visible`, `floating`, `maximized`, `urgent`, `hidden_tab`. These properties overlap; do not sum kinds. |
| `tag_windows` | Gauge: `monitor`, `tag` | Actual ordinary-tag membership, including inactive tabs. Special windows are excluded. Multitag windows count in every assigned tag; sticky windows are not duplicated onto unassigned tags. Tags are numbered 1–10. |
| `tag_selected` | Gauge: `monitor`, `tag` | Which ordinary tags are selected, independently of the special workspace. |
| `special_windows`, `special_open` | Gauges: `monitor` | Special workspace membership (even when hidden) and whether it is open. |
| `grouped` | Gauge: `monitor` | Current workspace's tabbed-pane mode setting. |
| `pane_windows` | Gauge: `monitor`, `pane` | Current workspace's tiled pane membership, including hidden tabs; panes 0 and 1. |
| `pane_ratio` | Gauge: `monitor` | Saved divider ratio, including after a pane collapses. |
| `app_windows` | Gauge: application identity | Mapped windows for each application. Zero remains after its last window closes. |
| `session_seconds_total` | Counter: `state` | Session time partitioned into `active`, `idle`, `locked`. |
| `session_state` | One-hot gauge: `state` | Current activity state. |
| `app_focus_seconds_total` | Counter: identity, `state` | Actual keyboard-focus time, partitioned by activity state. |
| `app_focus_retention_seconds` | Histogram: identity | Completed uninterrupted **active** focus dwells; buckets 1, 5, 15, 30, 60, 300, 1800 seconds and +Inf. |
| `app_events_total` | Counter: identity, `event` | `opened`, `closed`, `focus_entries`, `resize_layout`, `resize_interactive`, `resize_gestures`, `splits`, `pane_moves`. |
| `window_size_seconds_total` | Counter: `width`, `height` | Time-weighted popularity of outer window dimensions. Sizes round **up** to 256 logical pixels; 4352 means >4096. At most 17×17 series. Includes all mapped windows, even hidden ones. |
| `session_start_time_seconds` | Gauge | Unix time at metrics initialization. |
| `metrics_snapshot_time_seconds` | Gauge | Last successful snapshot's Unix time; use to detect stale data after a crash. |

**Application identity** is `app_id`, `class`, `executable`, captured once per
mapping. Wayland uses its advertised app ID; XWayland uses WM_CLASS as both
`app_id` and `class`. Wayland's `class` is empty. `executable` is empty unless
explicitly enabled; then it is the best-effort `/proc/PID/exe` target, **not**
command-line arguments. Missing/inaccessible PIDs yield an empty value.
X11 PIDs and all app identities are client-reported, not authenticated.
Titles never key cumulative app counters. An app changing its identity while
mapped keeps its original attribution until remap. Title-based queries identify
currently mapped windows by their **current** title; this is not a historical
archive that attributes each past focus interval to the title at that instant.

### Optional live-window series (`DWL_METRICS_WINDOWS=1`)

All numeric window metrics use only a session-local `window` mapping ID. Join
`window_info` to identify them; this avoids repeating titles and executable
paths on every numeric series.

| Metric | Meaning |
| --- | --- |
| `window_info` | Gauge 1 with `window`, app identity, and optional current `title`. |
| `window_focused` | Whether this managed client actually has keyboard focus. |
| `window_width_pixels`, `window_height_pixels` | Exact current outer dimensions in logical pixels, including borders. |
| `window_mapped_seconds_total` | Mapped lifetime. |
| `window_focus_seconds_total{state}` | Focus duration, partitioned by activity state. |
| `window_focus_retention_seconds` | Completed active focus-dwell histogram, with the same buckets as the app histogram. Join `window_info` for current app/class/executable/title. |
| `window_unfocused_seconds_total` | Mapped lifetime minus all focused time. This is separate from idle-but-focused time. |
| `window_focus_entries_total` | Actual keyboard focus entries. |
| `window_layout_size_changes_total` | Effective noninteractive size changes. Includes arrangement, maximize/fullscreen, monitor changes; **not** necessarily user resize actions. |
| `window_interactive_size_changes_total` | Effective size changes during interactive operations. |
| `window_resize_gestures_total` | Resize grabs with at least one effective size change; once per grab, not once per pointer event. |
| `window_splits_total` | Second-pane creations initiated by this window. A singleton crossing that immediately collapses is not a split. |
| `window_pane_moves_total` | Successful pane crossings, including splits but excluding within-pane tab reordering. |

Unmapped windows disappear from live series; remapping gets a new mapping ID
and new live-window counters. IDs restart with DWL, so do not use them as durable
identities across sessions. Per-app totals and the size distribution remain.

## Accounting semantics and limitations

- Durations use `CLOCK_MONOTONIC`, not wall-clock deltas or assumed timer ticks.
  A delayed callback splits time at the exact idle deadline. Suspend time is
  not included. Realtime is used only for start/freshness metadata.
- Input/focus accounting touches only session state and the focused window.
  Mapped lifetime derives from a mapping timestamp; size residency is settled
  per window before its geometry changes, at unmap, and at export. Application
  window counts derive from `opened - closed`, without per-application client scans.
- **Locked overrides idle, which overrides active**. A locker crash that leaves
  DWL locked continues accumulating locked time. Idle inhibitors do not convert
  inactivity into activity. This differs intentionally from shell idle policy.
- Input means compositor-delivered keyboard, button, scroll, and pointer motion,
  including virtual input and compositor-consumed shortcuts. Constrained/locked
  pointer motion still counts. Internal cursor/focus restoration does not.
- Focus comes from the seat's keyboard focus-change signal, not `focustop()` or
  `focused_client`. Layer-shell launchers, unmanaged X11 utilities, and lock
  surfaces do not accrue application focus time. A popup within one managed
  client does not create a different application/window identity.
- Focus loss, idle entry, or lock ends an active dwell. Renewed activity starts
  a new dwell even if the same client stayed selected. An ongoing dwell adds
  focus seconds but is not a histogram observation until it ends.
- Only mapped **managed** clients are windows. Layer-shell UI, popups, and
  unmanaged X11 surfaces are not counted. `visible` means DWL layout visibility,
  not occlusion testing; ordinary windows beneath the modal special workspace
  can remain visible without being focusable. Pane settings can remain enabled
  while the floating layout bypasses pane arrangement.
- Position-only moves and no-op arrangements do not increment size-change
  counters. Layout size changes and manual resize gestures are distinct.
- Application identities are retained for the session; their number is not
  hard-capped. Arbitrary client-supplied app IDs can increase cardinality.
  Per-window IDs create historical series even after unmap, and dynamic titles
  add churn and may expose documents, URLs, or secrets. Leave those options off
  unless the monitoring destination and retention policy are appropriate.
- Clean shutdown removes the file. After SIGKILL/crash it can remain; alert on
  stale `metrics_snapshot_time_seconds` and monitor collector scrape health.
  No on-disk counter history is persisted across DWL restarts.

## Example PromQL

Active focus share by application over the last hour:

```promql
sum by (app_id) (increase(dwl_app_focus_seconds_total{state="active"}[1h]))
/
scalar(sum(increase(dwl_app_focus_seconds_total{state="active"}[1h])))
```

Applications with the longest average completed focus dwell:

```promql
topk(10,
  sum by (app_id) (increase(dwl_app_focus_retention_seconds_sum[1h]))
  /
  sum by (app_id) (increase(dwl_app_focus_retention_seconds_count[1h]))
)
```

Most common size ranges by accumulated window-time, rather than noisy configure
request frequency:

```promql
topk(10, sum by (width, height) (increase(dwl_window_size_seconds_total[24h])))
```

Apps most often manually resized or used to initiate splits:

```promql
topk(10, sum by (app_id) (increase(dwl_app_events_total{event="resize_gestures"}[24h])))
topk(10, sum by (app_id) (increase(dwl_app_events_total{event="splits"}[24h])))
```

Identify the most-resized currently mapped windows (per-window export enabled):

```promql
topk(10, dwl_window_resize_gestures_total)
  * on (job, instance, window) group_left (app_id, class, executable, title)
    dwl_window_info
```

Mean completed dwell by current window title (both WINDOWS and TITLES enabled):

```promql
(dwl_window_focus_retention_seconds_sum / dwl_window_focus_retention_seconds_count)
  * on (job, instance, window) group_left (title, app_id)
    dwl_window_info
```

Stale exporter file, with a separate alert for absent/down collectors:

```promql
time() - dwl_metrics_snapshot_time_seconds > 10
```

## Verification

With the fully patched source built and its directory first on PATH:

```sh
packages/dwl/tests/run.sh /path/to/patched-dwl
nix-shell -p python3 wtype gtk3 pkg-config gcc wayland wayland-scanner prometheus.cli --run \
  'PATH=/path/to/patched-dwl:$PATH python3 packages/dwl/tests/metrics.py'
```

The C boundary fixture checks exact idle-deadline splitting, mutually exclusive
lock accounting, completed dwell buckets, input accounting independent of the
client list, timestamp-derived lifetimes, exact size residency across geometry/
export/unmap boundaries, unsigned lifecycle counts, size-change versus grab counts,
singleton versus real pane splits, and label escaping. The isolated real GTK /
headless compositor fixture checks live counts, privacy defaults, titles with
quotes/backslashes/newlines, tags, hidden tabs, special membership, fullscreen,
pane events, unchanged arrangements, active/idle focus accounting, closed-window
totals, lifetime/residency consistency, file permissions, preserved publication
errors (including EACCES when run unprivileged), clean shutdown, and exposition
with `promtool check metrics` when available. It never connects to a physical
seat or restarts the current desktop.
