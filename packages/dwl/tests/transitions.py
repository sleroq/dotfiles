"""Real headless grouped-window regression; never connects to the physical seat."""
import hashlib
import json
import os
from pathlib import Path
import shlex
import socket
import subprocess
import tempfile
import time


def run():
    with tempfile.TemporaryDirectory(prefix="dwl-transitions-") as directory:
        root = Path(directory)
        root.chmod(0o700)
        env = dict(os.environ, XDG_RUNTIME_DIR=str(root), WAYLAND_DISPLAY="wayland-0",
                   XDG_CONFIG_HOME=str(root / "config"), XDG_CACHE_HOME=str(root / "cache"),
                   GDK_BACKEND="wayland", GIO_USE_VFS="local", WLR_BACKENDS="headless",
                   WLR_HEADLESS_OUTPUTS="1", WLR_RENDERER="pixman",
                   PULSE_SERVER="unix:" + str(root / "disabled-pulse.sock"),
                   DWL_HELPER_SOCKET=str(root / "helper.sock"))
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

            def title():
                with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
                    connection.connect(env["DWL_HELPER_SOCKET"])
                    connection.sendall(b'"watch"\n')
                    return json.loads(connection.makefile().readline())["desktop"]["title"]

            def key(name, shift=False):
                command("wtype", "-M", "logo", *(("-M", "shift") if shift else ()), "-k", name,
                        *(("-m", "shift") if shift else ()), "-m", "logo")
                time.sleep(.2)

            def geometry(state, size):
                def observed():
                    lines = (root / "session.log").read_text().splitlines()
                    states = [x for x in lines if x.startswith("GTK maximized=")]
                    sizes = [x for x in lines if x.startswith("GTK size=")]
                    return states and sizes and states[-1] == f"GTK maximized={state}" and sizes[-1] == f"GTK size={size}"
                wait(observed)

            try:
                start("dwl")
                wait(lambda: (root / "wayland-0").exists())
                start("dwl-helper", "daemon")
                wait(lambda: (root / "helper.sock").exists())
                flags = shlex.split(subprocess.check_output(("pkg-config", "--cflags", "--libs", "gtk+-3.0"), text=True))
                command("cc", str(Path(__file__).with_name("transient.c")), "-o", str(root / "fixture"), *flags)
                protocol = str(Path(__file__).with_name("virtual-pointer.xml"))
                command("wayland-scanner", "client-header", protocol, str(root / "virtual-pointer.h"))
                command("wayland-scanner", "private-code", protocol, str(root / "virtual-pointer.c"))
                pointer_flags = shlex.split(subprocess.check_output(("pkg-config", "--cflags", "--libs", "wayland-client"), text=True))
                command("cc", "-I" + str(root), str(Path(__file__).with_name("drag.c")),
                        str(root / "virtual-pointer.c"), "-o", str(root / "drag"), *pointer_flags)
                start(str(root / "fixture"), "maximize", "A")
                geometry(1, "1276x716")
                key("space", True)  # explicit unmaximize before returning to tile
                geometry(0, "1260x708")
                key("space", True)
                geometry(0, "500x300")  # restore the small pre-maximize floating size
                resize_modifier = start("wtype", "-M", "logo", "-s", "1500", "-m", "logo")
                time.sleep(.2)
                command(str(root / "drag"), "resize")
                resize_modifier.wait(timeout=3)
                geometry(0, "640x360")
                for _ in range(2):
                    key("space", True)
                    geometry(0, "1260x708")
                    key("space", True)
                    geometry(0, "640x360")  # retain the last interactive resize, not the tile
                key("v", True)
                geometry(1, "1276x716")
                key("space", True)
                geometry(0, "1260x708")
                key("space", True)
                geometry(0, "640x360")  # maximize must not overwrite floating memory
                key("space", True)
                geometry(0, "1260x708")
                key("b")
                geometry(0, "1260x682")  # 26px strip reserved, including singleton
                command("grim", str(root / "singleton.png"))
                key("v", True)
                geometry(1, "1276x716")  # maximized grouped pane has no strip reservation
                command("grim", str(root / "maximized.png"))
                key("v", True)
                geometry(0, "1260x682")
                key("v")
                geometry(0, "1280x720")  # native fullscreen has no strip or borders
                command("grim", str(root / "fullscreen.png"))
                key("v")
                geometry(0, "1260x682")
                start(str(root / "fixture"), "normal", "B")
                wait(lambda: title() == "B")
                key("space", True)
                wait(lambda: title() == "B")  # retile must select B, not hidden A
                key("h")
                wait(lambda: title() == "A")
                key("l")
                wait(lambda: title() == "B")
                # Client.link order is B,A; title clicks must select hidden A.
                command("wlrctl", "pointer", "move", "-10000", "-10000")
                command("wlrctl", "pointer", "move", "1000", "15")
                command("wlrctl", "pointer", "click", "left")
                wait(lambda: title() == "A")
                assert "GTK button=" not in (root / "session.log").read_text(), "strip click leaked to application"
                command("wlrctl", "pointer", "move", "0", "100")
                command("wlrctl", "pointer", "click", "left")
                wait(lambda: "GTK button=1" in (root / "session.log").read_text())
                third = start(str(root / "fixture"), "normal", "boundary")
                wait(lambda: title() == "boundary")
                key("space", True)
                # Three tabs expose the actual left/right order, including wraparound.
                for name in ("B", "A", "boundary"):
                    key("l")
                    wait(lambda: title() == name)
                for name in ("A", "B", "boundary"):
                    key("h")
                    wait(lambda: title() == name)
                command("wlrctl", "pointer", "move", "-10000", "-10000")
                # 1264px strip: the second drawn tab starts at floor(1264/3)=421.
                command("wlrctl", "pointer", "move", "429", "15")
                command("wlrctl", "pointer", "click", "left")
                wait(lambda: title() == "B")
                command("wlrctl", "pointer", "move", "-409", "0")
                command("wlrctl", "pointer", "click", "left")
                wait(lambda: title() == "boundary")
                key("c", True)
                third.wait(timeout=5)
                command("wlrctl", "pointer", "move", "980", "0")
                command("wlrctl", "pointer", "click", "left")
                wait(lambda: title() == "A")
                key("l", True)  # split A into the right pane
                key("k")
                wait(lambda: title() == "B")
                key("j")
                wait(lambda: title() == "A")
                command("grim", str(root / "split.png"))
                key("c")  # pane orientation must not swap navigation axes
                key("k")
                wait(lambda: title() == "B")
                key("j")
                wait(lambda: title() == "A")
                key("u")
                key("space", True)
                # Initial size becomes dwl's restore geometry. gtk_window_resize()
                # changes GTK's buffer, not dwl's compositor-owned floating rectangle.
                start(str(root / "fixture"), "oversized", "C")
                wait(lambda: title() == "C")
                key("l")  # floating focus falls back to visible stack
                wait(lambda: title() != "C")
                key("k")  # pane navigation falls back to floating focus
                wait(lambda: title() == "C")
                geometry(0, "1800x1000")
                key("v", True)
                geometry(1, "1276x716")
                # Logo remains held while the dedicated virtual pointer performs a drag.
                modifier = start("wtype", "-M", "logo", "-s", "5000", "-m", "logo")
                time.sleep(.2)
                drag = subprocess.Popen((str(root / "drag"),), env=env, stdin=subprocess.PIPE,
                                        stdout=subprocess.PIPE, stderr=log, text=True)
                processes.append(drag)
                images = []
                for stage in ("outside", "commit", "release"):
                    assert drag.stdout.readline().strip() == stage
                    time.sleep(.2)
                    geometry(0, "1800x1000")  # moveresize explicitly clears native maximized state
                    image = root / (stage + ".png")
                    command("grim", str(image))
                    images.append(hashlib.sha256(image.read_bytes()).digest())
                    drag.stdin.write("\n")
                    drag.stdin.flush()
                drag.wait(timeout=3)
                assert drag.returncode == 0
                assert images[0] == images[1] == images[2], "offscreen geometry jumped across commit/release"
                modifier.wait(timeout=6)
                assert all(p.poll() is None for p in processes if p not in (drag, modifier, third, resize_modifier))
                print("PASS: floating size memory after resize/maximize, unmaximize/retile, grouped floating focus, H/L tabs, J/K panes in both orientations, title click, application click, strip reservation, stable offscreen drag")
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
