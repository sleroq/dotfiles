import { View, div, image } from "gpui-kit";
import { h_flex, v_flex, Popup } from "gpui-base";
import { agents, checking, openOverlay, props, run, settings, shared, setShared } from "herdr";

const TIPS = [
  "Click a tab's taskbar button to minimize it; click again to bring it back.",
  "Right-click a desktop folder to rename or close that space.",
  "Double-click a window's title bar to maximize or restore it.",
  "Start > Run... opens a command line in a new window.",
  "Need a break? Mines and Solitaire are on the desktop.",
];

export default class Teto extends View {
  init() {
    this.role = props()?.role ?? "mascot";
    this.opened = false;
    this.dismissed = new Set();
    this.tip = null;
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
    if (this.role === "host") {
      return div().id("teto-host").size_full().on_size_change(({ height }) => {
        if (checking() || this.opened || height <= 0) return;
        this.opened = true;
        openOverlay({
          mod: "teto98", kind: "window", frame: "none", key: "teto98",
          props: { role: "mascot" }, at: { x: 18, y: Math.max(0, height - 180) },
        });
      });
    }
    if (shared("win98.clippy") === "off") return div();

    const k = (shared("win98.scale") === 2 ? 2 : 1) / (Number(settings()?.zoom) || 1);
    const u = (n) => n * k;
    const a = this.news();
    let balloon = null;
    if (a) {
      const name = a.program?.name ?? a.app ?? "Your agent";
      const where = `${a.space_name} \\ ${a.tab_name}`;
      const text = a.status === "blocked"
        ? `${name} in ${where} is waiting for you.`
        : `${name} finished in ${where}.`;
      const dismiss = () => this.dismissed.add(`${a.address}:${a.status}`);
      balloon = this.balloon(u, text, [
        ["Take me there", () => { run("agent.focus", { terminal: a.address }); dismiss(); }],
        ["Not now", dismiss],
      ]);
    } else if (this.tip !== null) {
      balloon = this.balloon(u, TIPS[this.tip], [
        ["Next tip", () => { this.tip = (this.tip + 1) % TIPS.length; }],
        ["Close", () => { this.tip = null; }],
        ["Hide me", () => setShared("win98.clippy", "off")],
      ]);
    }

    const mascot = div().id("teto-mascot").relative().flex_none().cursor_pointer()
      .w(u(100)).h(u(100))
      .loop("top", { from: 0, to: u(a ? -5 : -2), period: a ? 800 : 1800 })
      .on_click((_e, cx) => {
        this.tip = this.tip === null ? 0 : null;
        cx.notify();
      })
      .child(
        div().id("teto-rest").absolute().inset_0().cursor_pointer()
          .active((s) => s.opacity(0))
          .child(image("mods/teto98/teto.png").w(u(100)).h(u(100))),
      )
      .child(
        div().id("teto-walk").absolute().inset_0().cursor_pointer().opacity(0)
          .active((s) => s.opacity(1))
          .child(image("mods/teto98/teto-walk.gif").id("teto-walk-image").w(u(100)).h(u(100))),
      );

    return Popup.new("teto-balloon", mascot).anchor("bottom_left")
      .font_family("Pixelated MS Sans Serif").text_size(u(11)).line_height(`${u(13)}px`)
      .text_color("#000000")
      .when(Boolean(balloon), (el) => el.content(balloon));
  }

  balloon(u, text, actions) {
    return v_flex().w(u(200)).p(u(8)).gap(u(8))
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
