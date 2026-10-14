# Build host selection

- `portable` is Darwin/macOS. Never build Linux systems on Darwin; use a Linux build host.
- Never build on `ru-relay` or `warsaw` (swarsaw): too little RAM/CPU. Build their systems locally on a capable Linux host; from `portable`, use `interplanetary` if reachable over SSH, otherwise `cumserver`.
- Build `cumserver` on itself by default. Offload large uncached builds (e.g. Rust/C++) to `interplanetary`, then copy the finished outputs to `cumserver`.
- Build `interplanetary` only on itself.
- For other Linux systems, build locally on a capable Linux host; from `portable`, use a capable Linux server.
- Keep build and deployment hosts separate: `--build-host` selects the builder, `--target-host` selects the deployment target. Copy and activate prebuilt closures on weak hosts; do not trigger target-side builds.
