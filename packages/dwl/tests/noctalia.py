"""Native shell regression in a disposable DWL/DBus session; never authenticates.

Needs dwl, noctalia, wtype, grim, gdbus and Python 3 on PATH.
Run through dbus-run-session, not on the desktop's session bus.
Only owned headless processes are started or signalled. Audio, idle actions,
polkit registration, network requests and production storage are disabled.
"""

import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import tempfile
import time


def run():
    for executable in ("dwl", "noctalia", "wtype", "grim", "gdbus"):
        assert shutil.which(executable), f"missing dependency: {executable}"
    assert os.environ.get("DBUS_SESSION_BUS_ADDRESS") != f"unix:path=/run/user/{os.getuid()}/bus", "use dbus-run-session"
    source = Path(__file__).resolve().parents[3] / "home/config/noctalia-dwl/config.toml"
    with tempfile.TemporaryDirectory(prefix="dwl-noctalia-") as directory:
        root = Path(directory)
        config = root / "config/noctalia"
        config.mkdir(parents=True)
        key = root / "storage.key"
        key.write_text(secrets.token_hex(32))
        key.chmod(0o600)
        (config / "config.toml").write_text(source.read_text().replace("@storageKey@", str(key)))
        (config / "zz-test.toml").write_text(f'''[shell]
polkit_agent = false
offline_mode = true
[storage]
key_source = "file"
key_file = "{key}"
[idle.behavior.lock]
enabled = false
[idle.behavior.screen-off]
enabled = false
[idle.behavior.suspend]
enabled = false
''')
        environment = dict(os.environ)
        environment.update(
            XDG_RUNTIME_DIR=str(root), XDG_CONFIG_HOME=str(root / "config"),
            XDG_CACHE_HOME=str(root / "cache"), XDG_STATE_HOME=str(root / "state"),
            WAYLAND_DISPLAY="wayland-0", XDG_CURRENT_DESKTOP="dwl", GDK_BACKEND="wayland",
            WLR_BACKENDS="headless", WLR_HEADLESS_OUTPUTS="1", WLR_RENDERER="pixman",
            LIBGL_ALWAYS_SOFTWARE="1", PIPEWIRE_REMOTE="nonexistent-noctalia-test",
        )
        for variable in ("DISPLAY", "NOTIFY_SOCKET", "SWAYSOCK", "I3SOCK", "WAYLAND_SOCKET"):
            environment.pop(variable, None)
        processes = []
        with (root / "session.log").open("w+") as log:
            def start(*arguments):
                process = subprocess.Popen(arguments, env=environment, stdout=log, stderr=log)
                processes.append(process)
                return process

            def command(*arguments):
                return subprocess.check_output(arguments, env=environment, text=True, stderr=log, timeout=5).strip()

            def message(*arguments):
                return command("noctalia", "msg", *arguments)

            def status():
                return json.loads(message("status"))

            def wait_for(predicate, description):
                deadline = time.monotonic() + 15
                while not predicate():
                    assert time.monotonic() < deadline, description
                    time.sleep(0.05)

            def shortcut(*arguments):
                command("wtype", *arguments)

            try:
                compositor = start("dwl")
                wait_for(lambda: (root / "wayland-0").exists(), "missing compositor socket")
                shell = start("noctalia")
                wait_for(lambda: any(root.glob("noctalia-wayland-*.sock")), "missing Noctalia socket")
                wait_for(lambda: status()["barVisible"], "bar not visible")
                shortcut("-M", "logo", "-k", "o", "-m", "logo")
                wait_for(lambda: status()["activePanelId"] == "launcher", "Super+O launcher binding")
                message("panel-close")
                shortcut("-M", "logo", "-M", "shift", "-k", "p", "-m", "shift", "-m", "logo")
                wait_for(lambda: status()["activePanelId"] == "launcher", "Super+Shift+P run binding")
                message("panel-close")
                for tab in ("audio", "calendar", "system", "notifications"):
                    assert message("panel-open", "control-center", tab) == "ok"
                    wait_for(lambda: status()["activePanelId"] == "control-center", f"missing {tab} panel")
                    message("panel-close")
                payload = "isolated-noctalia-fixture"
                assert message("clipboard-copy", payload) == "ok"
                wait_for(lambda: message("clipboard-text") == payload, "clipboard copy failed")
                entries = root / "state/noctalia/clipboard/entries"
                wait_for(lambda: any(entries.glob("*.enc")), "clipboard history not persisted")
                assert all(payload.encode() not in entry.read_bytes() for entry in entries.glob("*.enc"))
                shell.terminate()
                shell.wait(timeout=5)
                shell = start("noctalia")
                wait_for(lambda: any(root.glob("noctalia-wayland-*.sock")), "missing restarted Noctalia socket")
                shortcut("-M", "logo", "-k", "z", "-m", "logo")
                wait_for(lambda: status()["activePanelId"] == "clipboard", "Super+Z clipboard binding")
                shortcut("-k", "Return")
                wait_for(lambda: message("clipboard-text") == payload, "clipboard history lost on restart")
                owner = command("gdbus", "call", "--session", "--dest", "org.freedesktop.DBus", "--object-path", "/org/freedesktop/DBus", "--method", "org.freedesktop.DBus.GetConnectionUnixProcessID", "org.freedesktop.Notifications")
                assert owner == f"(uint32 {shell.pid},)", owner
                assert message("notification-show", "Smoke test", "Isolated DWL") == "ok"
                assert message("workspace-switch", "next") == "ok"
                command("grim", "-t", "ppm", str(root / "shell.ppm"))
                with (root / "shell.ppm").open("rb") as image:
                    assert image.readline() == b"P6\n"
                    width, height = map(int, image.readline().split())
                    assert image.readline() == b"255\n"
                    pixels = image.read()
                assert len(pixels) == width * height * 3 and len(set(pixels)) > 1
                shortcut("-M", "ctrl", "-M", "alt", "-k", "l", "-m", "alt", "-m", "ctrl")
                wait_for(lambda: status()["locked"], "Ctrl+Alt+L native lock binding")
                time.sleep(1)
                assert shell.poll() is None and compositor.poll() is None and status()["locked"]
                print("PASS: compiled launcher/run/clipboard/lock bindings; native panels, encrypted clipboard persistence, notification ownership, workspace IPC, rendering and lock lifetime")
                print("NOT TESTED: PAM unlock, physical monitor, UWSM/SDDM lifecycle, suspend/resume or real audio devices")
            except BaseException:
                log.flush()
                log.seek(0)
                print(log.read())
                raise
            finally:
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
