import { Background, PathBuilder, View, div, image } from "gpui-kit";
import { h_flex, v_flex, Popup } from "gpui-base";
import { agents, checking, exec, home, layout, panes, props, readTextFile, run, settings, shared, spaces, setShared, window as appWindow } from "herdr";

const TIPS = [
  "Click a tab's taskbar button to minimize it; click again to bring it back.",
  "Right-click a desktop folder to rename or close that space.",
  "Double-click a window's title bar to maximize or restore it.",
  "Start > Run... opens a command line in a new window.",
  "Need a break? Mines and Solitaire are on the desktop.",
];

const MARGIN = 8; // Popup's native window-edge inset, in logical pixels.
const SPRITE = 58;
const SEAT = 22 / 29;
const FEET = 24 / 29;
const WALK_FEET = 26 / 29;
const clamp = (n, min, max) => Math.max(min, Math.min(n, max));
const covers = ({ x1, x2 }, x) => x >= x1 && x <= x2;
const terminalFeeds = { pi: "pi", nvim: "nvim" };

function mainBlock() {
  return layout()?.children?.find((node) => node.id === "screen")?.children?.find((node) => node.id === "main");
}

function paneFrame(tab, main, zoom) {
  return tab && !tab.settled && !main?.hidden && Array.isArray(main?.padding)
    ? { x: main.padding[1] * zoom, y: main.padding[0] * zoom } : null;
}

// Herdr mods get the tab's panes, but not its split tree or pane bounds.
const GET_SPLITS = '{"id":1,"method":"doc.get","params":{"name":"herdr-app"}}';

async function splitTrees() {
  try {
    const { code, stdout } = await exec("sh", ["-c", 'printf "%s\\n" "$1" | hc connect', "teto98", GET_SPLITS], { timeout: 1500 });
    if (code !== 0) return new Map();
    const document = stdout.trim().split("\n").map((line) => JSON.parse(line)).find((reply) => reply.id === 1)?.result?.value;
    return new Map(document?.spaces.flatMap((space) => space.tabs.map((tab) => [tab.id, tab.root])) ?? []);
  } catch {
    return new Map();
  }
}

function inset(box, x, y) {
  return { x: box.x + x, y: box.y + y, width: box.width - 2 * x, height: box.height - 2 * y };
}

function splitBoxes(node, box, gap, zoom, boxes) {
  if (!node || node.hidden) return;
  if (node.type === "block") {
    boxes.set(node.id, box);
    return;
  }
  if (node.type !== "row" && node.type !== "column") return;

  const across = node.type === "row";
  const axis = across ? "width" : "height";
  const cross = across ? "x" : "y";
  const children = node.children.filter((child) => !child.hidden);
  const gutter = ((node.gap ?? gap) + (node.divider?.width ?? 0)) * zoom;
  const fixed = children.reduce((sum, child) => sum + (child.size?.px ?? 0) * zoom, 0);
  const weight = children.reduce((sum, child) => sum + (child.size?.px != null ? 0 : child.size?.weight ?? 1), 0);
  const free = Math.max(0, box[axis] - fixed - gutter * (children.length - 1));
  let start = box[cross];
  for (const child of children) {
    const size = child.size?.px != null ? child.size.px * zoom : free * (child.size?.weight ?? 1) / weight;
    splitBoxes(child, { ...box, [cross]: start, [axis]: size }, gap, zoom, boxes);
    start += size + gutter;
  }
}

// Herdr doesn't expose display scale, so the reported cell must fit the PTY grid.
function terminalGrid(report, box) {
  const { cols, rows, cell } = report;
  if (!Number.isInteger(cols) || !Number.isInteger(rows) || cols < 2 || rows < 1) return null;
  const fits = (step, count, length) => count * step <= length + 1 && (count + 1) * step >= length - 1;
  const deviceScale = cell && [1, 2, 1.25, 1.5, 1.75, 2.5, 3].find((scale) =>
    fits(cell.width / scale, cols, box.width) && fits(cell.height / scale, rows, box.height));
  // Without a measured cell, estimate within the one leftover row/column.
  const cw = deviceScale ? cell.width / deviceScale : box.width / (cols + 0.5);
  const ch = deviceScale ? cell.height / deviceScale : box.height / (rows + 0.5);
  if (cw < 2 || ch < 4) return null;
  return { cw, ch, x: box.x, y: box.y + Math.floor(Math.max(0, box.height - ch * rows) / 2) };
}

function terminalLedges(feed, target) {
  if (!target || feed?.address !== target.address) return [];
  const { report, address } = feed;
  const grid = terminalGrid(report, target.box);
  if (!grid) return [];

  return report.ledges.flatMap(({ id, row, x1, x2, kind }) => {
    if (typeof id !== "string" || !Number.isInteger(row) || row < 0 || row >= report.rows
      || x1 < 0 || x2 > report.cols || !(x2 > x1)) return [];
    return [{ id: `terminal:${address}:${target.feed}:${id}`, x1: grid.x + x1 * grid.cw, x2: grid.x + x2 * grid.cw,
      y: grid.y + (row + (kind === "rule" ? 0.5 : 0)) * grid.ch, rowHeight: grid.ch,
      terminal: true, working: target.working }];
  });
}

// First frame of teto-walk.gif on its original 29 px grid. Native images keep
// their aspect ratio, so draw these color runs as paths when the sprite bends.
const AIR_COLORS = ["#e34469", "#000000", "#b52775", "#e3ceaf", "#3a3a3a"];
const AIR_ROWS = `
..............11.............
.............11..............
.............1...............
..........222212222..........
...22222.23333333332.22222...
..2111112311111311132111112..
..2111123111111131113211112..
..2111121111311131111211112..
...23321113331113311112332...
...21112113441114431121112...
...21121133241144233112112...
....233233424144424132332....
....213321424444421323312....
.....212211444444412.212.....
......2..2122222212...2......
............25152............
...........2551552...........
..........225515522..........
.........24555555542.........
.........22111111122.........
..........222222222..........
............22.21.1..........
...........22...222..........
..........222................`;

function spriteRuns(art, colors, offset = 0) {
  const rows = art.trim().split("\n");
  return colors.map((_, i) => rows.flatMap((row, y) =>
    Array.from(row.matchAll(new RegExp(`${i + 1}+`, "g")), (m) => [m.index, m.index + m[0].length, y + offset])));
}

const AIR_RUNS = spriteRuns(AIR_ROWS, AIR_COLORS, 1);

function bentSprite(u, lean, stretch, widthScale) {
  const point = (x, y) => {
    const xx = Math.abs(lean) + x * widthScale - lean * (1 - y / 24);
    const yy = y * (1 + stretch);
    return [u(xx * SPRITE / 29), u(yy * SPRITE / 29)];
  };
  return paintSprite(AIR_RUNS, AIR_COLORS, point);
}

function paintSprite(layers, colors, point) {
  return layers.flatMap((runs, i) => {
    if (!runs.length) return [];
    const path = PathBuilder.fill();
    for (const [x1, x2, y] of runs) {
      path.add_polygon([point(x1, y), point(x2, y), point(x2, y + 1), point(x1, y + 1)]);
    }
    return [window.paint_path(path.build(), Background.solid(colors[i])).absolute().inset_0()];
  });
}

// Right-facing pixel art. Draw the mirrored paths for leftward walks rather
// than flipping the front-facing sprite. Each pose plants a foot at y=26.
const WALK_COLORS = ["#e34469", "#151019", "#b52775", "#e3ceaf", "#3a3a3a", "#26232d"];
const TURN_HEAD = `
.
..............11
.............13
.............1
..........222212222
....2222.23333333332.2222
...21111231111131113211112
...23332231111113111323332
...21112211131113111122112
....2332111333111331112332
....211211344111443112112
.....2332332411442332332
.....2132342414442413232
......22314244444231322
.......2.21444444412.2
..........222222222`;
const PROFILE_HEAD = `
.
...............11
..............13
.............1
..........222212222
......22223333333332
.....23322111331111332
.....213213332131111322
.....2332111121331111322
......232133323111311122
......232113244113441122
.......2233324114442412
........213424144442442
.........2342444444442
..........21444444412
...........222222222`;
const STANDING_BODY = `
.............25552
............2551552
...........245515542
...........225555522
...........221111122
............2266622
............226.252
............226.252
............222.222
............222.222`;
const WALK_BODIES = [
  `
.............25552
............2551552
...........245515522
...........225555542
...........221111122
............2266622
...........2262.2252
..........2262...2252
..........2222...2252
..........222....2222`,
  `
.............25552
............2551552
...........225515542
...........245555522
...........221111122
............2266622
............2262252
.............226252
..............22252
..............2222`,
  `
.............25552
............2551552
...........225515542
...........245555522
...........221111122
............2266622
...........2252.2262
..........2252...2262
..........2252...2222
..........222....2222`,
  `
.............25552
............2551552
...........245515522
...........225555542
...........221111122
............2266622
............2252262
............225222
............2222
.`,
];
const TURN_RUNS = spriteRuns(TURN_HEAD + STANDING_BODY, WALK_COLORS);
const PROFILE_RUNS = spriteRuns(PROFILE_HEAD + STANDING_BODY, WALK_COLORS);
const STEP_RUNS = WALK_BODIES.map((body, i) => spriteRuns(PROFILE_HEAD + body, WALK_COLORS, i === 3 ? 1 : 0));

function walkingSprite(u, { pose, direction, advance }) {
  const frame = Math.floor(advance / 7) % STEP_RUNS.length;
  const runs = pose === "step" ? STEP_RUNS[frame] : pose === "turn" ? TURN_RUNS : PROFILE_RUNS;
  return paintSprite(runs, WALK_COLORS, (x, y) => [
    u((direction < 0 ? 29 - x : x) * SPRITE / 29), u(y * SPRITE / 29),
  ]);
}

export default class Teto extends View {
  init(_p, cx) {
    this.dismissed = new Set();
    this.tip = null;
    this.barY = 0;
    this.body = null;
    this.grab = null;
    this.stroll = null;
    this.hovered = false;
    this.lean = 0;
    this.stretch = 0;
    this.lastTick = Date.now();
    this.hopAt = Infinity;
    this.terminalLedgeFeeds = new Map();
    this.supportMotion = null;
    this.splitTrees = new Map();
    this.splitReadAt = 0;
    this.overlayOpen = false;
    if (!checking() && props()?.role === "host") {
      this.schedule(cx, 16);
      cx.spawn(async (cx) => this.followTerminalLedges(cx));
      cx.spawn(async (cx) => this.followOverlays(cx));
    }
  }

  async followOverlays(cx) {
    // Popup content paints above Herdr's overlays, whose state is only exposed by the CLI.
    for (;;) {
      if (shared("win98.clippy") !== "off") {
        try {
          const { code, stdout } = await exec("herdr-app", ["status"], { timeout: 1000 });
          if (code === 0) {
            const open = JSON.parse(stdout).overlays.length > 0;
            if (this.overlayOpen !== open) {
              this.overlayOpen = open;
              cx.notify();
            }
          }
        } catch { /* Keep the last known visibility if the window cannot be queried. */ }
      }
      await cx.sleep(250);
    }
  }

  schedule(cx, delay) {
    this.tickDelay = delay;
    this.timer = cx.timer.after(delay, (cx) => {
      const now = Date.now();
      const dt = Math.min((now - this.lastTick) / 1000, 0.04);
      this.lastTick = now;
      const visible = this.body && this.world && shared("win98.clippy") !== "off";
      const moving = visible && this.tick(dt, now);
      const bending = visible && this.updateDeformation(dt, now);
      if (moving || bending) cx.notify();
      this.schedule(cx, visible && (this.grab || this.stroll || !this.body.perch) ? 16 : 250);
    });
  }

  async followTerminalLedges(cx) {
    const directory = `${home()}/.cache/teto98`;
    for (;;) {
      const targets = this.visibleTerminalTargets();
      const readings = await Promise.all(targets.map(async (target) => ({ target,
        source: await readTextFile(`${directory}/${target.feed}-${target.address}.json`).catch(() => null) })));
      this.updateTerminalLedges(readings, cx);
      await cx.sleep(this.terminalLedgeFeeds.size ? 40 : 240);
    }
  }

  updateTerminalLedges(readings, cx) {
    const next = new Map();
    for (const { target, source } of readings) {
      if (!source) continue;
      const previous = this.terminalLedgeFeeds.get(target.address);
      try {
        const report = previous?.source === source ? previous.report : JSON.parse(source);
        if (report?.version === 1 && Array.isArray(report.ledges)) {
          const { address } = target;
          next.set(address, { address, source, report, target });
        }
      } catch { /* A malformed snapshot isn't a surface. */ }
    }
    this.terminalLedgeFeeds = next;
    this.sampleSupport(cx);
  }

  sampleSupport(cx) {
    const id = this.body?.perch;
    const [kind, address] = id?.split(":", 2) ?? [];
    const feed = kind === "terminal" && this.terminalLedgeFeeds.get(address);
    const support = feed && terminalLedges(feed, feed.target).find((ledge) => ledge.id === id);
    if (!support) {
      this.supportMotion = null;
      if (kind === "terminal" && this.tickDelay > 16) this.wake(cx);
      return;
    }

    const now = Date.now();
    const previous = this.supportMotion?.id === id ? this.supportMotion : null;
    const dt = previous ? Math.max(0.016, (now - previous.at) / 1000) : 0.04;
    const speed = (support.y - (previous?.y ?? this.body.y)) / dt;
    // Treat one isolated row of scroll as a step, not a launch. Sustained
    // scrolling or several rows in one update can still break contact.
    const vy = speed + ((previous?.vy ?? 0) - speed) * Math.exp(-dt / 0.075);
    this.supportMotion = { id, y: support.y, vy, at: now };
    if ((support.y !== this.body.y || !covers(support, this.body.x)) && this.tickDelay > 16) this.wake(cx);
  }

  updateDeformation(dt, now) {
    if (this.body.perch) {
      this.lean = this.stretch = 0;
      return false;
    }
    const { vx, vy, ax = 0, ay = 0 } = this.grab ?? this.body;
    const fade = this.grab ? Math.exp(-Math.max(0, now - this.grab.at - 40) / 120) : 1;
    const { scale } = this.world;
    const lean = clamp((vx / 300 + ax / 5000) * fade / scale, -3.5, 3.5);
    // Downward motion elongates her; upward or sideways motion squashes her wider.
    const sideways = Math.abs(vx) / 900 + Math.abs(ax) / 28000;
    const vertical = vy / 950 + ay / 28000;
    const stretch = clamp((vertical > sideways ? vertical : Math.min(vertical, -sideways)) * fade / scale, -0.45, 0.65);

    const smooth = 1 - Math.exp(-dt / 0.026);
    const settle = (current, target, cutoff) => {
      const next = current + (target - current) * smooth;
      return Math.abs(target) < cutoff && Math.abs(next) < cutoff ? 0 : next;
    };
    const nextLean = settle(this.lean, lean, 0.12);
    const nextStretch = settle(this.stretch, stretch, 0.008);
    const changed = this.lean !== nextLean || this.stretch !== nextStretch;
    this.lean = nextLean;
    this.stretch = nextStretch;
    return changed;
  }

  wake(cx) {
    this.timer.cancel();
    this.lastTick = Date.now();
    this.schedule(cx, 16);
  }

  ledges() {
    const { width, high, frame } = this.world;
    const desktop = shared("teto98.desktop-ledges");
    const ledges = [...(desktop?.icons ?? [])];
    if (frame && desktop) {
      ledges.push({ id: "window-sill", x1: desktop.width + frame.x, x2: width - frame.x, y: this.barY - frame.y });
    }
    ledges.push({ id: "taskbar", x1: 0, x2: width, y: this.barY });
    for (const feed of this.terminalLedgeFeeds.values()) ledges.push(...terminalLedges(feed, feed.target));
    return ledges.filter((ledge) => (ledge.terminal || ledge.y >= high) && ledge.y <= this.barY);
  }

  tick(dt, now) {
    const b = this.body;
    const { left, right, high, gravity } = this.world;
    const ledges = this.ledges();
    const x = clamp(b.x, left, right);
    if (this.grab) return false;

    let support = ledges.find((ledge) => ledge.id === b.perch && covers(ledge, x));
    if (support?.terminal && this.supportMotion?.id === support.id) {
      const { vy } = this.supportMotion;
      const speedLimit = support.rowHeight * 12;
      if (support.y < b.y && vy < -speedLimit) {
        // A rising surface pushes her up, then her momentum carries her past it.
        b.y = support.y;
        b.vy = Math.max(vy, -360 * this.world.scale);
        support = null;
      } else if (support.y > b.y && vy > speedLimit) {
        // A dropping surface can't pull her down. Let gravity close the gap.
        support = null;
      }
    }
    if (support) {
      const shifted = b.x !== x || b.y !== support.y;
      b.x = x;
      b.y = support.y;
      const idle = !support.working && !this.hovered && this.tip === null && appWindow().active;
      if (this.stroll) {
        if (!idle) this.stopStroll(now);
        else this.walk(dt, now, support);
        return true;
      }
      if (idle && now >= this.hopAt) {
        if (Math.random() >= 0.18 || !this.startStroll(support)) this.hop(now, ledges);
        return true;
      }
      return shifted;
    }

    if (this.stroll) this.stopStroll(now);
    this.supportMotion = null;
    b.perch = null;
    const nextX = clamp(x + b.vx * dt, left, right);
    if ((nextX === left && b.vx < 0) || (nextX === right && b.vx > 0)) b.vx = 0;
    b.vy += gravity * dt;
    const ceiling = Math.min(high, b.y);
    const nextY = Math.max(ceiling, b.y + b.vy * dt);
    if (nextY === ceiling && b.vy < 0) b.vy = 0;

    // Swept collision: only catch ledges from above, even on a slow frame.
    const hit = ledges.filter((ledge) => {
      if (ledge.y < b.y || ledge.y > nextY) return false;
      const t = nextY === b.y ? 0 : (ledge.y - b.y) / (nextY - b.y);
      return covers(ledge, x + (nextX - x) * t) && covers(ledge, nextX);
    }).sort((a, b) => a.y - b.y)[0];
    b.x = nextX;
    if (hit) {
      b.y = hit.y;
      b.vx = b.vy = 0;
      b.perch = hit.id;
      this.hopAt = now + 8000 + Math.random() * 7000;
    } else {
      // If a resize put her past the floor, start just above its new edge.
      b.y = Math.min(nextY, this.barY);
    }
    return true;
  }

  startStroll(support) {
    const { left, right, scale } = this.world;
    const min = Math.max(left, support.x1 + 7 * scale);
    const max = Math.min(right, support.x2 - 7 * scale);
    const x = this.body.x;
    if (x < min || x > max) return false;
    const directions = [-1, 1].filter((direction) =>
      (direction < 0 ? x - min : max - x) >= 50 * scale);
    if (!directions.length) return false;
    const direction = directions[Math.floor(Math.random() * directions.length)];
    const available = direction < 0 ? x - min : max - x;
    this.stroll = { direction, advance: 0, pose: "turn", phase: 0, elapsed: 0,
      distance: Math.min((58 + Math.random() * 42) * scale, available) };
    return true;
  }

  walk(dt, now, support) {
    const stroll = this.stroll;
    const { left, right, scale } = this.world;
    const min = Math.max(left, support.x1 + 7 * scale);
    const max = Math.min(right, support.x2 - 7 * scale);
    const x = this.body.x;
    if (x < min || x > max) return this.stopStroll(now);
    if (stroll.phase === 2) {
      const available = stroll.direction < 0 ? x - min : max - x;
      const distance = Math.min(52 * scale * dt, stroll.distance - stroll.advance * scale, available);
      this.body.x += stroll.direction * distance;
      stroll.advance += distance / scale;
      if (distance >= available || stroll.advance * scale >= stroll.distance) {
        stroll.phase = 3;
        stroll.pose = "stand";
        stroll.elapsed = 0;
      }
      return;
    }
    stroll.elapsed += dt;
    if (stroll.elapsed < (stroll.pose === "turn" ? 0.115 : 0.1)) return;
    stroll.elapsed = 0;
    stroll.phase++;
    if (stroll.phase === 5) this.stopStroll(now);
    else stroll.pose = ["turn", "stand", "step", "stand", "turn"][stroll.phase];
  }

  stopStroll(now) {
    this.stroll = null;
    this.hopAt = now + 8000 + Math.random() * 7000;
  }

  hop(now, ledges = this.ledges()) {
    this.stroll = null;
    const b = this.body;
    const { left, right, high, gravity, scale } = this.world;
    this.hopAt = now + 8000;
    const reachable = ledges.filter((ledge) => ledge.id !== b.perch && ledge.id !== "taskbar" && ledge.y >= high
      && ledge.x2 >= left && ledge.x1 <= right && Math.abs(clamp(b.x, ledge.x1, ledge.x2) - b.x) < 250 * scale);
    const nearby = reachable.filter((ledge) => Math.abs(ledge.y - b.y) < 250 * scale);
    const terminal = reachable.filter((ledge) => ledge.terminal);
    const targets = terminal.length && !b.perch?.startsWith("terminal:") ? terminal : nearby.length ? nearby : reachable;
    const target = targets[Math.floor(Math.random() * targets.length)];
    const inset = target ? Math.min(12 * scale, (target.x2 - target.x1) / 2) : 0;
    const x = clamp(target ? clamp(b.x, target.x1 + inset, target.x2 - inset)
      : b.x + (Math.random() < 0.5 ? -1 : 1) * 88 * scale, left, right);
    const y = target?.y ?? this.barY;
    const peak = Math.max(Math.min(high, b.y), Math.min(b.y, y) - 38 * scale);
    const up = Math.sqrt(2 * Math.max(0, b.y - peak) / gravity);
    const down = Math.sqrt(2 * (y - peak) / gravity);
    b.vx = (x - b.x) / Math.max(0.1, up + down);
    b.vy = -gravity * up;
    b.perch = null;
  }

  pickUp(e, cx) {
    cx.stop_propagation();
    const { x, y } = e.position;
    this.grab = { startX: x, startY: y, dx: this.body.x - x, dy: this.body.y - y, x, y, vx: 0, vy: 0, at: Date.now(), moved: false };
    this.wake(cx);
  }

  drag(e, cx) {
    const g = this.grab;
    if (!g) return;
    const { x, y } = e.position;
    if (!g.moved && Math.hypot(x - g.startX, y - g.startY) < 4) return;
    const now = Date.now();
    if (this.stroll) this.stopStroll(now);
    const dt = Math.max(0.012, (now - g.at) / 1000);
    const vx = 0.35 * g.vx + 0.65 * (x - g.x) / dt;
    const vy = 0.35 * g.vy + 0.65 * (y - g.y) / dt;
    g.ax = (vx - g.vx) / dt;
    g.ay = (vy - g.vy) / dt;
    g.vx = vx;
    g.vy = vy;
    Object.assign(g, { x, y, at: now, moved: true });
    this.body.x = clamp(x + g.dx, this.world.left, this.world.right);
    this.body.y = clamp(y + g.dy, this.world.high, this.barY - 1);
    this.body.perch = null;
    cx.notify();
  }

  release(cx) {
    const g = this.grab;
    if (!g) return;
    this.grab = null;
    this.hovered = false;
    if (g.moved) {
      const speed = Date.now() - g.at < 110 ? 1 : 0;
      const limit = 780 * this.world.scale;
      this.body.vx = clamp(g.vx * speed, -limit, limit);
      this.body.vy = clamp(g.vy * speed, -limit, limit);
    } else {
      if (this.stroll) this.stopStroll(Date.now());
      this.tip = this.tip === null ? 0 : null;
    }
    cx.notify();
  }

  news() {
    const list = agents();
    const active = new Set(list.map((a) => `${a.address}:${a.status}`));
    for (const key of this.dismissed) {
      if (!active.has(key)) this.dismissed.delete(key);
    }
    return list
      .filter((a) => (a.status === "blocked" || a.status === "done") && !a.focused)
      .filter((a) => !this.dismissed.has(`${a.address}:${a.status}`))
      .sort((a, b) => (a.status === "blocked") - (b.status === "blocked") || a.seq - b.seq)
      .pop() ?? null;
  }

  render() {
    if (checking() || props()?.role !== "host") return div();
    const host = div().id("teto-host").relative().size_full().on_size_change(({ height }, cx) => {
      this.barY = height;
      cx.notify();
    });
    const { width, height } = window.viewport_size();
    const scale = shared("win98.scale") === 2 ? 2 : 1;
    const size = SPRITE * scale;
    if (this.overlayOpen || shared("win98.clippy") === "off"
      || this.barY <= size + MARGIN || width <= size + 2 * MARGIN) {
      this.world = null;
      this.grab = null;
      this.hovered = false;
      if (this.stroll) this.stopStroll(Date.now());
      return host;
    }

    const zoom = Number(settings()?.zoom) || 1;
    const px = (n) => n / zoom; // Styles zoom; viewport, size and pointer events already use logical pixels.
    const u = (n) => px(n * scale);
    const left = MARGIN + size / 2;
    const right = width - left;
    const space = spaces().find((s) => s.active);
    const tab = space?.tabs.find((t) => t.active);
    const frame = paneFrame(tab, mainBlock(), zoom);
    const high = MARGIN + size * FEET;
    this.world = { width, zoom, left, right, high, gravity: 1000 * scale, scale, frame };
    this.body ??= { x: clamp(45 * scale, left, right), y: high, vx: 0, vy: 0, perch: null };

    const b = this.body;
    const strolling = this.stroll;
    const seated = b.perch && !strolling;
    const stretch = b.perch ? 0 : this.stretch;
    const lean = b.perch ? 0 : this.lean;
    const widthScale = (1 + stretch) ** -0.65;
    const artWidth = size * (widthScale + 2 * Math.abs(lean) / 29);
    const x = clamp(b.x, left, right) - artWidth / 2;
    // A seated sprite aligns at the hips; the walk aligns at the soles.
    const footing = seated ? SEAT : strolling ? WALK_FEET : FEET;
    const top = b.y - size * (footing + stretch * 12 / 29);
    const y = Math.max(MARGIN, top);
    const anchor = (id, x, y) => Popup.new(id, div().w(0).h(0)).absolute().left(px(x)).top(px(y)).w(0).h(0);
    const grabbing = this.grab?.moved;
    const release = (_e, cx) => { cx.stop_propagation(); this.release(cx); };
    const crop = px(y - top);
    const artHeight = u(SPRITE * (strolling ? WALK_FEET : 25 / 29) * (1 + stretch));
    const pixels = strolling ? walkingSprite(u, strolling) : lean || stretch ? bentSprite(u, lean, stretch, widthScale)
      : [image(seated ? "mods/teto98/teto.png" : "mods/teto98/teto-walk.gif").absolute().size(u(SPRITE))];
    const art = div().absolute().left(0).top(-crop).w(px(artWidth)).h(artHeight).children(pixels);
    const sprite = div().id("teto-mascot").relative().w(px(artWidth)).h(Math.max(0, artHeight - crop))
      .overflow_hidden().cursor_pointer().child(art);

    if (grabbing) {
      // Grow the pointer target only during a drag, not while the mascot is idle.
      return host.child(anchor("teto-drag-layer", MARGIN, MARGIN).content(
        div().id("teto-drag").relative().w(px(width - 2 * MARGIN)).h(px(height - 2 * MARGIN))
          .cursor_pointer().on_mouse_move((e, cx) => this.drag(e, cx))
          .on_mouse_up("left", release)
          .on_hover((hovered, cx) => { if (!hovered) this.release(cx); })
          .child(sprite.absolute().left(px(x - MARGIN)).top(px(y - MARGIN))),
      ));
    }
    sprite.on_hover((hovered, cx) => {
      this.hovered = hovered;
      if (!hovered && this.grab) this.drag({ position: window.mouse_position() }, cx);
    }).on_mouse_down("left", (e, cx) => this.pickUp(e, cx))
      .on_mouse_move((e, cx) => this.drag(e, cx))
      .on_mouse_up("left", release)
      .on_mouse_down("right", (_e, cx) => {
        cx.stop_propagation();
        if (!b.perch) return;
        this.hop(Date.now());
        this.wake(cx);
        cx.notify();
      });
    const balloon = this.message(u);
    return host.child(anchor("teto-layer", x, y).content(sprite))
      .when(Boolean(balloon), (el) => el.child(anchor("teto-balloon", x, y - 6).anchor("bottom_left").content(balloon)));
  }

  visibleTerminalTargets() {
    if (!this.world) return [];
    const space = spaces().find((s) => s.active);
    const tab = space?.tabs.find((t) => t.active);
    const main = mainBlock();
    const { zoom, width } = this.world;
    const frame = paneFrame(tab, main, zoom);
    const desktop = shared("teto98.desktop-ledges");
    if (!frame || space.machine || !desktop) return [];

    const tabPanes = panes().filter((pane) => pane.tab === tab.id);
    const zoomed = tabPanes.find((pane) => pane.zoomed);
    const shown = (zoomed ? [zoomed] : tabPanes).filter((pane) => /^t[a-z0-9]+$/.test(pane.terminal ?? "")
      && Object.hasOwn(terminalFeeds, pane.program?.key) && !pane.scroll?.from_bottom);
    if (!shown.length) return [];

    const chrome = main.content?.pane;
    const area = inset({ x: desktop.width, y: 0, width: width - desktop.width, height: this.barY }, frame.x, frame.y);
    const boxes = new Map();
    if (zoomed || tabPanes.length === 1) {
      boxes.set(shown[0].pane, area);
    } else {
      // Refresh split sizes for divider drags without blocking viewport reads.
      const now = Date.now();
      if (now >= this.splitReadAt) {
        this.splitReadAt = Infinity;
        void splitTrees().then((trees) => {
          this.splitTrees = trees;
          this.splitReadAt = Date.now() + 600;
        });
      }
      splitBoxes(this.splitTrees.get(tab.id), area, chrome?.gap ?? 0, zoom, boxes);
    }

    const [padX, padY] = settings()?.terminal_padding ?? [4, 2];
    const header = (chrome?.header?.height ?? 0) * zoom;
    return shown.flatMap((pane) => {
      const bounds = boxes.get(pane.pane);
      if (!bounds) return [];
      const border = (pane.focused ? chrome?.focus?.width ?? chrome?.border?.width : chrome?.border?.width) ?? 0;
      const box = inset(bounds, (border + padX) * zoom, (border + padY) * zoom);
      box.y += header;
      box.height -= header;
      return [{ address: pane.terminal, feed: terminalFeeds[pane.program.key], box, working: pane.status === "working" }];
    });
  }

  message(u) {
    const a = this.news();
    if (a) {
      const name = a.program?.name ?? a.app ?? "Your agent";
      const where = `${a.space_name} ${a.tab_name}`;
      const text = a.status === "blocked"
        ? `${name} in ${where} is waiting for you.`
        : `${name} finished in ${where}.`;
      const dismiss = () => this.dismissed.add(`${a.address}:${a.status}`);
      return this.balloon(u, text, [
        ["Take me there", () => { run("agent.focus", { terminal: a.address }); dismiss(); }],
        ["Not now", dismiss],
      ]);
    }
    if (this.tip === null) return null;
    return this.balloon(u, TIPS[this.tip], [
      ["Next tip", () => { this.tip = (this.tip + 1) % TIPS.length; }],
      ["Close", () => { this.tip = null; }],
      ["Hide me", () => setShared("win98.clippy", "off")],
    ]);
  }

  balloon(u, text, actions) {
    return v_flex().w(u(200)).p(u(8)).gap(u(8))
      .font_family("Pixelated MS Sans Serif").text_size(u(11)).line_height(`${u(13)}px`).text_color("#000000")
      .bg("#fff8e8").border(u(2)).border_color("#a54f6b")
      .child(div().text_color("#542436").child(text))
      .child(v_flex().gap(u(3)).children(actions.map(([label, action], i) =>
        h_flex().id(`teto-action-${i}`).items_center().gap(u(5)).cursor_pointer()
          .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
          .on_click((_e, cx) => { action(); cx.notify(); })
          .child(div().w(u(5)).h(u(5)).bg("#a54f6b"))
          .child(div().text_color("#000080").underline().child(label)),
      )));
  }
}
