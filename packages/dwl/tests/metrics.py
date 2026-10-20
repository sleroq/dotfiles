"""Opt-in real headless metrics regression. Run with the candidate dwl on PATH.

Requires cc, pkg-config gtk+-3.0 and wtype; optionally validates with promtool.
No physical seat, installed configuration, or existing compositor is used.
"""
import json
import math
import os
from pathlib import Path
import re
import shlex
import shutil
import stat
import subprocess
import tempfile
import time


SAMPLE = re.compile(r'([a-zA-Z_:][a-zA-Z_0-9:]*)(?:\{(.*)\})? ([^ ]+)$')
LABEL = re.compile(r'([a-zA-Z_][a-zA-Z_0-9]*)=("(?:[^"\\]|\\[\\"n])*")(?:,|$)')


def parse(text):
    """Parse the emitted text subset, rejecting duplicate samples/bad escaping."""
    result = []
    seen = set()
    for line in text.splitlines():
        if not line or line.startswith('#'):
            continue
        match = SAMPLE.fullmatch(line)
        assert match, line
        name, raw, value = match.groups()
        labels = {}
        offset = 0
        while raw and offset < len(raw):
            label = LABEL.match(raw, offset)
            assert label, line
            key, encoded = label.groups()
            assert key not in labels, line
            labels[key] = json.loads(encoded)
            offset = label.end()
        identity = (name, tuple(sorted(labels.items())))
        assert identity not in seen, line
        seen.add(identity)
        value = float(value)
        assert math.isfinite(value) and value >= 0, line
        result.append((name, labels, value))
    assert result, 'empty exposition'
    return result


def values(samples, name, **labels):
    return [value for metric, tags, value in samples
            if metric == name and all(tags.get(k) == v for k, v in labels.items())]


def total(samples, name, **labels):
    found = values(samples, name, **labels)
    assert found, (name, labels)
    return sum(found)


def run():
    with tempfile.TemporaryDirectory(prefix='dwl-metrics-') as directory:
        root = Path(directory)
        root.chmod(0o700)
        private = root / 'private'
        private.mkdir(mode=0o700)
        path = private / 'snapshot.prom'
        env = dict(os.environ, XDG_RUNTIME_DIR=str(root), WAYLAND_DISPLAY='wayland-0',
                   XDG_CONFIG_HOME=str(root / 'config'), XDG_CACHE_HOME=str(root / 'cache'),
                   GDK_BACKEND='wayland', GIO_USE_VFS='local', WLR_BACKENDS='headless',
                   WLR_HEADLESS_OUTPUTS='1', WLR_RENDERER='pixman',
                   PULSE_SERVER='unix:' + str(root / 'disabled-pulse.sock'),
                   DWL_METRICS_FILE=str(path), DWL_METRICS_IDLE_SECONDS='1')
        for key in ('NOTIFY_SOCKET', 'DWL_METRICS_WINDOWS', 'DWL_METRICS_TITLES',
                    'DWL_METRICS_EXECUTABLES'):
            env.pop(key, None)
        processes = []
        with (root / 'session.log').open('w+') as log:
            def command(*args):
                return subprocess.run(args, env=env, stdout=log, stderr=log,
                                      check=True, timeout=10)

            def start(*args):
                process = subprocess.Popen(args, env=env, stdout=log, stderr=log)
                processes.append(process)
                return process

            def wait(predicate):
                deadline = time.monotonic() + 10
                while True:
                    result = predicate()
                    if result:
                        return result
                    assert compositor.poll() is None, (root / 'session.log').read_text()
                    assert time.monotonic() < deadline, (root / 'session.log').read_text()
                    time.sleep(.05)

            def snapshot():
                return parse(path.read_text()) if path.exists() else []

            def expect(name, value, **labels):
                return wait(lambda: (s := snapshot()) and
                            values(s, name, **labels) == [value] and s)

            def fresh():
                before = path.stat().st_ino
                return wait(lambda: path.stat().st_ino != before and snapshot())

            def key(name, shift=False):
                command('wtype', '-M', 'logo', *(('-M', 'shift') if shift else ()),
                        '-k', name, *(('-m', 'shift') if shift else ()), '-m', 'logo')

            def check_prometheus():
                if shutil.which('promtool'):
                    with path.open() as source:
                        subprocess.run(('promtool', 'check', 'metrics'), stdin=source,
                                       stdout=log, stderr=log, check=True, timeout=10)

            def stop():
                compositor.terminate()
                compositor.wait(timeout=5)
                assert compositor.returncode == 0
                assert not path.exists(), 'normal exit left a stale snapshot'

            try:
                flags = shlex.split(subprocess.check_output(
                    ('pkg-config', '--cflags', '--libs', 'gtk+-3.0'), text=True))
                command('cc', str(Path(__file__).with_name('transient.c')),
                        '-o', str(root / 'fixture'), *flags)
                protocol = str(Path(__file__).with_name('virtual-pointer.xml'))
                command('wayland-scanner', 'client-header', protocol, str(root / 'virtual-pointer.h'))
                command('wayland-scanner', 'private-code', protocol, str(root / 'virtual-pointer.c'))
                pointer_flags = shlex.split(subprocess.check_output(
                    ('pkg-config', '--cflags', '--libs', 'wayland-client'), text=True))
                command('cc', '-I' + str(root), str(Path(__file__).with_name('drag.c')),
                        str(root / 'virtual-pointer.c'), '-o', str(root / 'drag'), *pointer_flags)
                env.update(DWL_METRICS_WINDOWS='1', DWL_METRICS_TITLES='1',
                           DWL_METRICS_EXECUTABLES='1')
                compositor = start('dwl')
                wait(lambda: (root / 'wayland-0').exists())
                expect('dwl_windows', 0, kind='all')
                assert stat.S_IMODE(path.stat().st_mode) == 0o600
                title = 'metrics "quoted" \\ title\nsecond line'
                first = start(str(root / 'fixture'), 'ordinary', title)
                expect('dwl_windows', 1, kind='all')
                key('space', True)  # float at the fixture's 500x300 restore size
                s = expect('dwl_windows', 1, kind='floating')
                width = total(s, 'dwl_window_width_pixels')
                height = total(s, 'dwl_window_height_pixels')
                modifier = start('wtype', '-M', 'logo', '-s', '1500', '-m', 'logo')
                time.sleep(.2)
                command(str(root / 'drag'), 'resize')
                modifier.wait(timeout=3)
                s = wait(lambda: (s := snapshot()) and
                         total(s, 'dwl_app_events_total', event='resize_interactive') > 0 and s)
                assert total(s, 'dwl_window_width_pixels') > width
                assert total(s, 'dwl_window_height_pixels') > height
                key('space', True)
                expect('dwl_windows', 0, kind='floating')
                second = start(str(root / 'fixture'), 'ordinary', 'metrics B')
                s = expect('dwl_app_windows', 2, app_id='dwl-ordinary-test')
                assert any(tags.get('title') == title for name, tags, _ in s
                           if name == 'dwl_window_info'), 'title did not round-trip'
                assert len(values(s, 'dwl_window_info')) == 2
                assert total(s, 'dwl_window_focused') == 1
                assert all(tags['executable'].startswith('/') for name, tags, _ in s
                           if name == 'dwl_window_info')
                check_prometheus()
                assert total(s, 'dwl_app_events_total', event='opened') == 2
                expect('dwl_tag_windows', 2, tag='1')
                key('b')
                expect('dwl_grouped', 1)
                expect('dwl_windows', 1, kind='hidden_tab')
                expect('dwl_pane_windows', 2, pane='0')
                # The newly mapped tiled window is first in client order. Move to
                # the last tab before crossing the boundary to create a split.
                key('h')
                key('l', True)
                s = expect('dwl_pane_windows', 1, pane='1')
                assert total(s, 'dwl_app_events_total', event='splits') == 1
                assert total(s, 'dwl_app_events_total', event='pane_moves') == 1
                key('h', True)  # merge into existing pane: transfer, not split
                s = expect('dwl_pane_windows', 2, pane='0')
                assert total(s, 'dwl_app_events_total', event='splits') == 1
                assert total(s, 'dwl_app_events_total', event='pane_moves') == 2
                assert total(s, 'dwl_app_events_total', event='resize_layout') > 0
                before = total(s, 'dwl_app_events_total', event='resize_layout')
                key('q')  # selecting the same tag arranges without changing size
                s = fresh()
                assert total(s, 'dwl_app_events_total', event='resize_layout') == before
                key('v')
                expect('dwl_windows', 1, kind='fullscreen')
                key('v')
                key('2')
                expect('dwl_tag_windows', 1, tag='2')
                key('w')
                key('x', True)
                expect('dwl_special_windows', 1)
                expect('dwl_tag_windows', 0, tag='2')
                key('x')
                expect('dwl_special_open', 1)
                key('x')
                s = expect('dwl_special_open', 0)
                assert total(s, 'dwl_special_windows') == 1, 'hidden special lost membership'
                key('q')
                command('wtype', '-k', 'a')  # reset idle deadline with real virtual input
                s = fresh()
                active = total(s, 'dwl_app_focus_seconds_total', state='active')
                idle = total(s, 'dwl_app_focus_seconds_total', state='idle')
                time.sleep(2.2)
                s = fresh()
                assert total(s, 'dwl_session_state', state='idle') == 1
                assert 0 <= total(s, 'dwl_app_focus_seconds_total', state='active') - active <= 1.1
                assert total(s, 'dwl_app_focus_seconds_total', state='idle') > idle + 1
                assert total(s, 'dwl_app_focus_seconds_total', state='active') > 0
                mapped = total(s, 'dwl_window_mapped_seconds_total')
                assert math.isclose(total(s, 'dwl_window_size_seconds_total'), mapped, abs_tol=1e-6)
                assert math.isclose(total(s, 'dwl_window_unfocused_seconds_total') +
                                    total(s, 'dwl_window_focus_seconds_total'), mapped, abs_tol=1e-6)
                for process in (first, second):
                    process.terminate()
                    process.wait(timeout=5)
                s = expect('dwl_windows', 0, kind='all')
                assert total(s, 'dwl_app_events_total', event='closed') == 2
                assert total(s, 'dwl_app_events_total', event='opened') == 2
                assert total(s, 'dwl_app_windows') == 0
                assert not any('window' in tags for _, tags, _ in s)
                size_seconds = total(s, 'dwl_window_size_seconds_total')
                assert size_seconds >= mapped
                s = fresh()
                assert total(s, 'dwl_window_size_seconds_total') == size_seconds
                check_prometheus()
                stop()
                # Defaults must not expose live identities/titles, even with clients.
                env.pop('DWL_METRICS_WINDOWS')
                env.pop('DWL_METRICS_TITLES')
                env.pop('DWL_METRICS_EXECUTABLES')
                compositor = start('dwl')
                wait(lambda: (root / 'wayland-0').exists())
                client = start(str(root / 'fixture'), 'ordinary', title)
                s = expect('dwl_windows', 1, kind='all')
                assert not any('window' in tags or 'title' in tags for _, tags, _ in s)
                assert all(tags['executable'] == '' for _, tags, _ in s if 'executable' in tags)
                client.terminate()
                client.wait(timeout=5)
                stop()
                # A nonexistent parent is unwritable even when tests run as root.
                env['DWL_METRICS_FILE'] = str(root / 'missing' / 'snapshot.prom')
                compositor = start('dwl')
                wait(lambda: (root / 'wayland-0').exists())
                time.sleep(2.2)
                assert compositor.poll() is None, 'publication failure killed dwl'
                compositor.terminate()
                compositor.wait(timeout=5)
                # Cleanup's unlink must not replace mkstemp's EACCES with ENOENT.
                # Root bypasses directory write permissions, so it cannot reproduce this case.
                if os.geteuid() != 0:
                    blocked = root / 'blocked'
                    blocked.mkdir(mode=0o500)
                    env['DWL_METRICS_FILE'] = str(blocked / 'snapshot.prom')
                    env['LC_ALL'] = 'C'
                    compositor = start('dwl')
                    wait(lambda: (root / 'wayland-0').exists())
                    expected = f"cannot publish {env['DWL_METRICS_FILE']}: Permission denied"
                    wait(lambda: expected in (root / 'session.log').read_text())
                    assert compositor.poll() is None, 'publication failure killed dwl'
                    compositor.terminate()
                    compositor.wait(timeout=5)
                print('PASS: metrics lifecycle, privacy, text format, workspace/pane events, idle accounting and publication errors')
            finally:
                for process in reversed(processes):
                    if process.poll() is None:
                        process.terminate()
                        try:
                            process.wait(timeout=3)
                        except subprocess.TimeoutExpired:
                            process.kill()
                            process.wait()


if __name__ == '__main__':
    run()
