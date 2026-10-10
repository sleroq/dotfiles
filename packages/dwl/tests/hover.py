"""Isolated headless desktop regression; dependencies are listed in ../README.md."""

import json
import os
from pathlib import Path
import shutil
import shlex
import socket
import subprocess
import tempfile
import time


def run():
    with tempfile.TemporaryDirectory(prefix="dwl-hover-") as directory:
        root = Path(directory)
        config = root / "eww"
        shutil.copytree(Path(__file__).resolve().parents[3] / "home/config/eww-dwl", config)
        environment = dict(os.environ)
        environment.update(
            XDG_RUNTIME_DIR=str(root),
            WAYLAND_DISPLAY="wayland-0",
            XDG_CURRENT_DESKTOP="dwl",
            GDK_BACKEND="wayland",
            WLR_BACKENDS="headless",
            WLR_HEADLESS_OUTPUTS="1",
            WLR_RENDERER="pixman",
            DWL_HELPER_SOCKET=str(root / "helper.sock"),
            DWL_EWW_CONFIG=str(config),
            PULSE_SERVER="unix:/nonexistent-dwl-hover-test-pulse",
        )
        environment.pop("NOTIFY_SOCKET", None)
        processes = []
        with (root / "session.log").open("w+") as log:
            def command(*arguments):
                subprocess.run(arguments, env=environment, stdout=log, stderr=log, check=True, timeout=10)

            def start(*arguments):
                processes.append(subprocess.Popen(arguments, env=environment, stdout=log, stderr=log))

            def wait_socket(name):
                deadline = time.monotonic() + 5
                while not (root / name).exists():
                    if time.monotonic() >= deadline:
                        raise AssertionError(f"missing socket: {name}")
                    time.sleep(0.01)

            def snapshot():
                with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
                    connection.settimeout(5)
                    connection.connect(environment["DWL_HELPER_SOCKET"])
                    connection.sendall(b'"watch"\n')
                    return json.loads(connection.makefile().readline())

            def move(dx, dy, drawer, expected):
                # One motion must enter/leave the right surface: no compensating second event.
                command("wlrctl", "pointer", "move", str(dx), str(dy))
                time.sleep(0.3)
                actual = snapshot()["drawers"]
                assert actual[drawer] == expected, (drawer, expected, actual)

            try:
                start("dwl")
                wait_socket("wayland-0")
                start("dwl-helper", "daemon")
                wait_socket("helper.sock")
                start("eww", "--config", str(config), "daemon", "--no-daemonize", "--force-wayland")
                command("eww", "--config", str(config), "open-many", "sidebar", "top-sensor", "audio-sensor")
                flags = shlex.split(subprocess.check_output(
                    ("pkg-config", "--cflags", "--libs", "gtk+-3.0"), text=True, env=environment,
                ))
                command("cc", str(Path(__file__).with_name("transient.c")), "-o", str(root / "transient"), *flags)

                def wait_geometry(maximized, size):
                    deadline = time.monotonic() + 5
                    while True:
                        log.flush()
                        observations = (root / "session.log").read_text().splitlines()
                        states = [line for line in observations if line.startswith("GTK maximized=")]
                        sizes = [line for line in observations if line.startswith("GTK size=")]
                        if states and sizes and states[-1] == f"GTK maximized={int(maximized)}" and sizes[-1] == f"GTK size={size}":
                            return
                        assert time.monotonic() < deadline, (maximized, size, states, sizes)
                        time.sleep(0.01)

                def maximize_toggle():
                    command("wtype", "-M", "logo", "-M", "shift", "-k", "v", "-m", "shift", "-m", "logo")

                start(str(root / "transient"), "maximize")
                # 1280x720 headless output minus the 52px sidebar and 2px borders.
                wait_geometry(True, "1224x716")
                maximize_toggle()
                wait_geometry(False, "500x300")
                maximize_toggle()
                wait_geometry(True, "1224x716")
                maximize_toggle()
                wait_geometry(False, "500x300")
                command("wtype", "-M", "logo", "-M", "shift", "-k", "c", "-m", "shift", "-m", "logo")
                processes[-1].wait(timeout=5)

                for _ in range(3):
                    move(-10000, -10000, "top", False)
                    move(676, 1, "top", True)
                    move(0, 100, "top", True)
                    move(-500, 550, "top", False)
                    move(-10000, -10000, "audio", False)
                    move(1279, 360, "audio", True)
                    move(-100, -200, "audio", True)
                    move(-1000, 450, "audio", False)
                start(str(root / "transient"))
                time.sleep(0.3)
                assert snapshot()["desktop"]["title"] == "DWL-parent-test"

                def shortcut(shift=False):
                    modifiers = ("-M", "shift") if shift else ()
                    releases = ("-m", "shift") if shift else ()
                    command("wtype", "-M", "logo", *modifiers, "-k", "x", *releases, "-m", "logo")
                    time.sleep(0.15)

                shortcut(shift=True)
                shortcut()
                command("wtype", "d")
                time.sleep(0.3)
                desktop = snapshot()["desktop"]
                assert desktop["title"] == "DWL-transient-test"
                assert not desktop["workspaces"][0]["occupied"], "overlay dialog escaped into normal tags"
                shortcut()
                assert snapshot()["desktop"]["title"] == "", "hidden overlay dialog remained focusable"
                shortcut()
                assert snapshot()["desktop"]["title"] == "DWL-transient-test", "overlay dialog state lost"
                command("wtype", "-M", "logo", "-M", "shift", "-k", "c", "-m", "shift", "-m", "logo")
                time.sleep(0.15)
                assert snapshot()["desktop"]["title"] == "DWL-parent-test"
                shortcut()
                start(str(root / "transient"), "underlay")
                time.sleep(0.3)
                assert snapshot()["desktop"]["fullscreen"], "underlying client did not request fullscreen"
                shortcut()
                command("wtype", "d")
                time.sleep(0.3)
                shortcut()
                desktop = snapshot()["desktop"]
                assert desktop["title"] == "DWL-underlay-test" and desktop["fullscreen"], "overlay dialog cancelled underlying fullscreen"
                print("PASS: initial native maximize/restore, hover handoff, transient overlay visibility/focus, underlying fullscreen preservation")
            except BaseException:
                log.flush()
                log.seek(0)
                print(log.read())
                raise
            finally:
                subprocess.run(("eww", "--config", str(config), "kill"), env=environment, stdout=log, stderr=log, timeout=5)
                for process in reversed(processes):
                    if process.poll() is None:
                        process.terminate()
                    process.wait(timeout=5)


if __name__ == "__main__":
    run()
