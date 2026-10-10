"""Real headless grouped-window regression; never connects to the physical seat."""
import hashlib
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import time


def run(overlay_only=False, overlay_modal=False, overlay_fullscreen=False, overlay_spawn=False):
    with tempfile.TemporaryDirectory(prefix="dwl-transitions-") as directory:
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

            def title():
                return subprocess.check_output((str(root / "ipc-title"),), env=env,
                                               text=True, timeout=5).rstrip("\n")

            def key(name, shift=False):
                command("wtype", "-M", "logo", *(("-M", "shift") if shift else ()), "-k", name,
                        *(("-m", "shift") if shift else ()), "-m", "logo")
                time.sleep(.2)

            def geometry(state, size, fixture_log=None):
                def observed():
                    lines = (fixture_log or root / "session.log").read_text().splitlines()
                    states = [x for x in lines if x.startswith("GTK maximized=")]
                    sizes = [x for x in lines if x.startswith("GTK size=")]
                    return states and sizes and states[-1] == f"GTK maximized={state}" and sizes[-1] == f"GTK size={size}"
                wait(observed)

            def spawn_overlay():
                underlay_log = root / "underlay.log"
                ordinary_log = root / "ordinary.log"
                with underlay_log.open("w") as output:
                    underlay = subprocess.Popen((str(root / "fixture"), "underlay"),
                                                env=env, stdout=output, stderr=log)
                    processes.append(underlay)
                wait(lambda: title() == "DWL-underlay-test")
                geometry(0, "1280x720", underlay_log)
                key("x")  # empty special workspace must own the new window
                with ordinary_log.open("w") as output:
                    processes.append(subprocess.Popen((str(root / "fixture"), "ordinary", "ordinary-spawn"),
                                                      env=env, stdout=output, stderr=log))
                wait(lambda: title() == "ordinary-spawn")
                geometry(0, "500x300", ordinary_log)
                geometry(0, "1280x720", underlay_log)
                key("w")
                assert title() == "ordinary-spawn"
                key("x")
                wait(lambda: title() != "ordinary-spawn")
                key("q")
                wait(lambda: title() == "DWL-underlay-test")
                geometry(0, "1280x720", underlay_log)
                key("x")
                wait(lambda: title() == "ordinary-spawn")
                command("wtype", "-k", "d")
                wait(lambda: title() == "DWL-transient-test")
                key("w")
                assert title() == "DWL-transient-test"
                key("x")
                wait(lambda: title() not in ("ordinary-spawn", "DWL-transient-test"))
                key("x")
                wait(lambda: title() == "DWL-transient-test")
                key("c", True)
                wait(lambda: title() == "ordinary-spawn")
                key("x")
                underlay.terminate()
                underlay.wait(timeout=3)
                closed_log = root / "closed.log"
                with closed_log.open("w") as output:
                    processes.append(subprocess.Popen((str(root / "fixture"), "ordinary", "closed-spawn"),
                                                      env=env, stdout=output, stderr=log))
                wait(lambda: title() == "closed-spawn")
                geometry(0, "1260x708", closed_log)
                key("x")
                wait(lambda: title() == "ordinary-spawn")
                key("x")
                wait(lambda: title() == "closed-spawn")
                print("PASS: ordinary special spawn, forced float, workspace-independent membership, transient inheritance, fullscreen underlay and closed-special tiling")

            def overlay_send():
                fixture_log = root / "overlay-send.log"
                with fixture_log.open("w") as output:
                    processes.append(subprocess.Popen((str(root / "fixture"), "normal", "overlay-send"),
                                                      env=env, stdout=output, stderr=log))
                wait(lambda: title() == "overlay-send")
                geometry(0, "500x300", fixture_log)
                key("x", True)
                key("x")
                wait(lambda: title() == "overlay-send")
                key("2")  # a normal workspace send must remove overlay membership
                wait(lambda: title() != "overlay-send")
                key("x")  # hide the overlay before visiting the destination
                key("w")
                wait(lambda: title() == "overlay-send")
                geometry(0, "500x300", fixture_log)
                key("x")  # ordinary windows must not follow the open overlay
                key("q")
                wait(lambda: title() != "overlay-send")
                key("w")
                wait(lambda: title() != "overlay-send")
                key("x")  # close the empty modal overlay before ordinary focus
                wait(lambda: title() == "overlay-send")
                key("x", True)
                key("x")
                wait(lambda: title() == "overlay-send")
                key("2")  # return to the current workspace from the open overlay
                wait(lambda: title() != "overlay-send")
                key("x")
                wait(lambda: title() == "overlay-send")
                geometry(0, "500x300", fixture_log)
                print("PASS: overlay send to normal/current workspace, visibility, focus and floating size")

            def modal_overlay():
                start(str(root / "fixture"), "maximize", "underlay")
                wait(lambda: title() == "underlay")
                start(str(root / "fixture"), "normal", "special")
                wait(lambda: title() == "special")
                key("x", True)
                key("x")
                wait(lambda: title() == "special")
                command("grim", str(root / "open.png"))
                for direction in ("h", "l", "j", "k"):
                    key(direction)
                    assert title() == "special"
                before = (root / "session.log").read_text().count("GTK button=")
                command("wlrctl", "pointer", "move", "-10000", "-10000")
                command("wlrctl", "pointer", "move", "100", "100")
                command("wlrctl", "pointer", "click", "left")
                time.sleep(.2)
                assert title() == "special"
                assert (root / "session.log").read_text().count("GTK button=") == before
                key("w")
                assert title() == "special"
                key("q")
                assert title() == "special"
                key("x")
                wait(lambda: title() == "underlay")
                command("grim", str(root / "closed.png"))
                # Sample the underlay and special interior in the real rendered output.
                def pixels(path):
                    data = subprocess.check_output(("convert", str(path), "rgb:-"), env=env)
                    return [tuple(data[(y * 1280 + x) * 3:(y * 1280 + x) * 3 + 3])
                            for x, y in ((100, 100), (640, 400))]
                opened, closed = pixels(root / "open.png"), pixels(root / "closed.png")
                assert sum(opened[0]) < sum(closed[0]), (opened, closed)
                assert opened[1] == closed[1], "special client was dimmed"
                key("x")
                command("grim", str(root / "reopened.png"))
                assert pixels(root / "reopened.png") == opened
                print("PASS: modal special focus, blocked underlay clicks, workspace switches, dim and restore")

            def fullscreen_overlay():
                fixture_log = root / "fullscreen.log"
                with fixture_log.open("w") as output:
                    processes.append(subprocess.Popen((str(root / "fixture"), "normal", "special-fullscreen"),
                                                      env=env, stdout=output, stderr=log))
                wait(lambda: title() == "special-fullscreen")
                geometry(0, "500x300", fixture_log)
                key("x", True)  # leave the first client hidden while mapping the second
                start(str(root / "fixture"), "normal", "special-float")
                wait(lambda: title() == "special-float")
                key("x", True)
                key("x")
                wait(lambda: title() == "special-float")
                key("l")
                wait(lambda: title() == "special-fullscreen")
                key("v")
                geometry(0, "1280x720", fixture_log)
                # Upstream blocks cycling away from childless fullscreen clients.
                command("wtype", "-k", "d")
                wait(lambda: title() == "DWL-transient-test")
                command("wlrctl", "pointer", "move", "-10000", "-10000")
                command("wlrctl", "pointer", "move", "640", "360")
                command("wlrctl", "pointer", "click", "left")
                assert title() == "DWL-transient-test"
                # Keep its parent link (and focus policy) but uncover the center.
                key("x", True)

                def raise_float():
                    # Focusstack explicitly raises the selected client's scene node.
                    if title() != "special-float":
                        key("l")
                    assert title() == "special-float"
                    command("wlrctl", "pointer", "move", "-10000", "-10000")
                    command("wlrctl", "pointer", "move", "640", "360")
                    command("wlrctl", "pointer", "click", "left")
                    wait(lambda: title() == "special-fullscreen")

                raise_float()
                for _ in range(3):
                    key("x")
                    key("x")
                    raise_float()
                    key("w")
                    raise_float()
                    key("q")
                    raise_float()
                key("v")
                geometry(0, "500x300", fixture_log)
                key("v")
                geometry(0, "1280x720", fixture_log)
                raise_float()
                key("v")
                geometry(0, "500x300", fixture_log)
                print("PASS: special fullscreen above keyboard-raised float, pointer hit, hide/reopen, workspace arrange, fullscreen transient and geometry restore")

            try:
                start("dwl")
                wait(lambda: (root / "wayland-0").exists())
                protocol = str(Path(__file__).with_name("dwl-ipc-unstable-v2.xml"))
                command("wayland-scanner", "client-header", protocol, str(root / "dwl-ipc.h"))
                command("wayland-scanner", "private-code", protocol, str(root / "dwl-ipc.c"))
                ipc_flags = shlex.split(subprocess.check_output(("pkg-config", "--cflags", "--libs", "wayland-client"), text=True))
                command("cc", "-I" + str(root), str(Path(__file__).with_name("ipc-title.c")),
                        str(root / "dwl-ipc.c"), "-o", str(root / "ipc-title"), *ipc_flags)
                flags = shlex.split(subprocess.check_output(("pkg-config", "--cflags", "--libs", "gtk+-3.0"), text=True))
                command("cc", str(Path(__file__).with_name("transient.c")), "-o", str(root / "fixture"), *flags)
                if overlay_spawn:
                    spawn_overlay()
                    return
                if overlay_fullscreen:
                    fullscreen_overlay()
                    return
                if overlay_modal:
                    modal_overlay()
                    return
                if overlay_only:
                    overlay_send()
                    return
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
                overlay_send()
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
    run(overlay_only="--overlay-send" in sys.argv, overlay_modal="--overlay-modal" in sys.argv,
        overlay_fullscreen="--overlay-fullscreen" in sys.argv, overlay_spawn="--overlay-spawn" in sys.argv)
