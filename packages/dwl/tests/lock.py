"""Isolated lock-lifetime regression (Linux /proc; never authenticates).

Needs fixed system dwl, dwl-helper, eww, swaylock, grim, wlrctl, Python 3.
Run: nix-shell -p wlrctl --run 'python3 packages/dwl/tests/lock.py'
No real PAM unlock is tested. Only owned headless processes are signalled.
The owned swaylock wrapper delays startup 300ms to exceed Eww's default.

Eww 48f5aa8 crates/eww/src/widgets/widget_definitions.rs:530 defaults
button timeout to 200ms; widgets/mod.rs:16 runs /bin/sh -c and kills its
immediate child on timeout. The sidebar overrides acquisition to 10s;
wait 11s here to check daemon lifetime beyond that acquisition deadline.
"""

import os
from pathlib import Path
import shlex
import shutil
import signal
import subprocess
import tempfile
import time


def run():
    for executable in ("dwl", "dwl-helper", "eww", "swaylock", "grim", "wlrctl"):
        assert shutil.which(executable), f"missing dependency: {executable}"
    swaylock = shutil.which("swaylock")
    with tempfile.TemporaryDirectory(prefix="dwl-lock-") as directory:
        root = Path(directory)
        config = root / "eww"
        shutil.copytree(Path(__file__).resolve().parents[3] / "home/config/eww-dwl", config)
        assert ':onclick "swaylock -f" :timeout "10s" :tooltip "Lock"' in (config / "eww.yuck").read_text()
        xdg_config = root / "config"
        (xdg_config / "swaylock").mkdir(parents=True)
        (xdg_config / "swaylock/config").write_text("color=123456\nignore-empty-password\n")
        # Instrument completion without changing the sidebar command or its arguments.
        bin_directory = root / "bin"
        bin_directory.mkdir()
        wrapper = bin_directory / "swaylock"
        wrapper.write_text(
            f"#!/bin/sh\nsleep 0.3\n{shlex.quote(swaylock)} -C {shlex.quote(str(xdg_config / 'swaylock/config'))} \"$@\"\n"
            f"status=$?\nprintf '%s\\n' \"$status\" > {shlex.quote(str(root / 'action-exit'))}\n"
            "exit \"$status\"\n"
        )
        wrapper.chmod(0o700)
        environment = dict(os.environ)
        environment.update(
            XDG_RUNTIME_DIR=str(root), XDG_CONFIG_HOME=str(xdg_config), XDG_CACHE_HOME=str(root / "cache"),
            WAYLAND_DISPLAY="wayland-0", XDG_CURRENT_DESKTOP="dwl", GDK_BACKEND="wayland",
            WLR_BACKENDS="headless", WLR_HEADLESS_OUTPUTS="1", WLR_RENDERER="pixman",
            DWL_HELPER_SOCKET=str(root / "helper.sock"), DWL_EWW_CONFIG=str(config),
            PULSE_SERVER="unix:/nonexistent-dwl-lock-test-pulse",
            PATH=str(bin_directory) + os.pathsep + environment["PATH"],
        )
        for variable in ("NOTIFY_SOCKET", "SWAYSOCK", "I3SOCK", "WAYLAND_SOCKET"):
            environment.pop(variable, None)
        processes = []

        def lockers():
            owned = []
            for entry in Path("/proc").iterdir():
                if not entry.name.isdigit():
                    continue
                try:
                    # swaylock disables dumpability: /proc/environ may be unreadable.
                    arguments = (entry / "cmdline").read_bytes().split(b"\0")
                    if str(xdg_config / "swaylock/config").encode() in arguments and b"swaylock" in arguments[0]:
                        owned.append(int(entry.name))
                except (FileNotFoundError, ProcessLookupError, PermissionError):
                    continue
            return owned

        with (root / "session.log").open("w+") as log:
            def command(*arguments):
                subprocess.run(arguments, env=environment, stdout=log, stderr=log, check=True, timeout=5)

            def start(*arguments):
                process = subprocess.Popen(arguments, env=environment, stdout=log, stderr=log)
                processes.append(process)
                return process

            def wait_for(predicate, description):
                deadline = time.monotonic() + 5
                while not predicate():
                    assert time.monotonic() < deadline, description
                    time.sleep(0.01)

            def capture(name):
                path = root / name
                command("grim", "-t", "ppm", str(path))
                with path.open("rb") as image:
                    assert image.readline() == b"P6\n"
                    width, height = map(int, image.readline().split())
                    assert image.readline() == b"255\n"
                    pixels = image.read()
                assert len(pixels) == width * height * 3
                return width, height, pixels

            try:
                compositor = start("dwl")
                wait_for(lambda: (root / "wayland-0").exists(), "missing compositor socket")
                start("dwl-helper", "daemon")
                wait_for(lambda: (root / "helper.sock").exists(), "missing helper socket")
                eww = start("eww", "--config", str(config), "daemon", "--no-daemonize", "--force-wayland")
                wait_for(lambda: any(root.glob("eww-server_*")), "missing Eww socket")
                command("eww", "--config", str(config), "open", "sidebar")
                time.sleep(1)
                width, height, _ = capture("sidebar.ppm")
                command("wlrctl", "pointer", "move", "-10000", "-10000")
                command("wlrctl", "pointer", "move", "26", str(height - 24))
                clicked = time.monotonic()
                command("wlrctl", "pointer", "click", "left")
                wait_for(lambda: (root / "action-exit").exists(), "sidebar lock action did not return")
                elapsed = time.monotonic() - clicked
                assert (root / "action-exit").read_text().strip() == "0", "swaylock startup failed"
                assert 0.3 <= elapsed < 2, f"unexpected delayed daemon startup: {elapsed:.3f}s"
                wait_for(lambda: bool(lockers()), "missing owned swaylock daemon")
                # swaylock also forks a PAM helper, with the same command line.
                owned_lockers = set(lockers())
                time.sleep(max(0, 11 - (time.monotonic() - clicked)))
                assert set(lockers()) == owned_lockers, "locker disappeared after action timeout"
                assert compositor.poll() is None and eww.poll() is None
                _, _, pixels = capture("locked.ppm")
                assert pixels == bytes.fromhex("123456") * (width * height), "minimal swaylock color not visible"
                for pid in owned_lockers:
                    os.kill(pid, signal.SIGKILL)
                wait_for(lambda: not lockers(), "owned locker survived SIGKILL")
                time.sleep(0.3)
                _, _, pixels = capture("failed-closed.ppm")
                assert pixels == bytes((25, 25, 25)) * (width * height), f"missing fail-closed dark gray background: byte values {set(pixels)}"
                assert compositor.poll() is None, "compositor exited on locker disappearance"
                terminated = time.monotonic()
                compositor.terminate()
                compositor.wait(timeout=2)
                shutdown = time.monotonic() - terminated
                print(f"PASS: actual sidebar click; swaylock -f returned in {elapsed:.3f}s; daemon alive at 11s")
                print(f"PASS: killed owned locker; {width}x{height} fail-closed RGB(25,25,25); locked dwl SIGTERM exit in {shutdown:.3f}s")
                print("NOT TESTED: normal PAM unlock, physical session, uwsm/SDDM lifecycle or historical incident attribution")
            except BaseException:
                log.flush()
                log.seek(0)
                print(log.read())
                raise
            finally:
                for pid in lockers():
                    os.kill(pid, signal.SIGKILL)
                for process in reversed(processes):
                    if process.poll() is None:
                        process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait(timeout=5)


if __name__ == "__main__":
    run()
