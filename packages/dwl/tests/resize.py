"""Four-corner resize regression in an isolated headless compositor."""
import os
from pathlib import Path
import shlex
import subprocess
import tempfile
import time


def run():
    tests = Path(__file__).resolve().parent
    with tempfile.TemporaryDirectory(prefix="dwl-resize-") as directory:
        root = Path(directory)
        root.chmod(0o700)
        env = dict(os.environ, XDG_RUNTIME_DIR=str(root), WAYLAND_DISPLAY="wayland-0",
                   XDG_CONFIG_HOME=str(root / "config"), XDG_CACHE_HOME=str(root / "cache"),
                   GDK_BACKEND="wayland", GIO_USE_VFS="local", WLR_BACKENDS="headless",
                   WLR_HEADLESS_OUTPUTS="1", WLR_RENDERER="pixman",
                   PULSE_SERVER="unix:" + str(root / "disabled-pulse.sock"))
        env.pop("NOTIFY_SOCKET", None)
        processes = []
        with (root / "session.log").open("w+") as log:
            def command(*args):
                return subprocess.run(args, env=env, stdout=log, stderr=log, check=True, timeout=10)

            def start(*args):
                process = subprocess.Popen(args, env=env, stdout=log, stderr=log)
                processes.append(process)
                return process

            def wait(predicate):
                deadline = time.monotonic() + 8
                while not predicate():
                    assert time.monotonic() < deadline, (root / "session.log").read_text()
                    time.sleep(.05)

            def geometry(size):
                def observed():
                    sizes = [line for line in (root / "session.log").read_text().splitlines()
                             if line.startswith("GTK size=")]
                    return sizes and sizes[-1] == f"GTK size={size}"
                wait(observed)

            try:
                flags = shlex.split(subprocess.check_output(
                    ("pkg-config", "--cflags", "--libs", "gtk+-3.0"), text=True))
                command("cc", str(tests / "transient.c"), "-o", str(root / "fixture"), *flags)
                protocol = str(tests / "virtual-pointer.xml")
                command("wayland-scanner", "client-header", protocol, str(root / "virtual-pointer.h"))
                command("wayland-scanner", "private-code", protocol, str(root / "virtual-pointer.c"))
                flags = shlex.split(subprocess.check_output(
                    ("pkg-config", "--cflags", "--libs", "wayland-client"), text=True))
                command("cc", "-I" + str(root), str(tests / "drag.c"),
                        str(root / "virtual-pointer.c"), "-o", str(root / "drag"), *flags)
                compositor = start("dwl")
                wait(lambda: (root / "wayland-0").exists())
                fixture = start(str(root / "fixture"), "normal")
                geometry("500x300")
                # Centered outer rectangle starts at (388,208), with 2px borders.
                pointer_positions = ("98,98", "518,113", "133,293", "553,293")
                for quadrant, size in enumerate(("535x315", "570x330", "605x345", "640x360")):
                    modifier = start("wtype", "-M", "logo", "-s", "1500", "-m", "logo")
                    time.sleep(.2)
                    command(str(root / "drag"), "resize", str(quadrant), "388", "208")
                    modifier.wait(timeout=3)
                    assert modifier.returncode == 0
                    geometry(size)
                    pointers = [line for line in (root / "session.log").read_text().splitlines()
                                if line.startswith("GTK pointer=")]
                    assert pointers and pointers[-1] == f"GTK pointer={pointer_positions[quadrant]}", pointers
                assert compositor.poll() is None and fixture.poll() is None
                print("PASS: TL/TR/BL/BR resize, 500x300 → 535x315 → 570x330 → 605x345 → 640x360")
            finally:
                for process in reversed(processes):
                    if process.poll() is None:
                        process.terminate()
                        try:
                            process.wait(timeout=3)
                        except subprocess.TimeoutExpired:
                            process.kill()
                            process.wait()


if __name__ == "__main__":
    run()
