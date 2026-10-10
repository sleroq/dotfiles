# dwl-helper

The daemon binds `$DWL_HELPER_SOCKET` (default `$XDG_RUNTIME_DIR/dwl-helper.sock`)
and creates the schema's initial default snapshot before sending `READY=1` to
`$NOTIFY_SOCKET`. Readiness does not wait for optional audio or compositor data;
backend failures are logged to stderr. Audio introspection publishes complete
batches of server defaults, outputs, inputs and streams.

SIGTERM/SIGINT return through socket cleanup. Startup refuses a live socket and
removes an abandoned socket only when connecting returns connection-refused.
Watcher writes have a 100ms timeout; failed watchers are dropped.

Development needs `pkg-config` and `libpulseaudio` for linking. Run `cargo test`,
`cargo clippy --workspace --all-targets --all-features -- -D warnings`, and
`cargo machete` here. When running outside Nix packaging, the PulseAudio library
must also be on the runtime library search path.

Drawer hover callbacks use `drawer top enter --source sensor` (or `leave`) for
edge sensors; drawer content uses the default `--source content`. Each drawer
stays open while either source is active, including when content enter arrives
before sensor leave. Once both leave, it closes after 180ms. Toggle cancels the
pending close and clears hover tracking. JSON drawer commands may omit `source`
for content, or supply `"Sensor"` / `"Content"`; snapshots are unchanged.
