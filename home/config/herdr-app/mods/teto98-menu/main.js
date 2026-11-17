import { View, div } from "gpui-kit";
import { h_flex, v_flex } from "gpui-base";
import { closeOverlay, keys, panes, props, run, terminals } from "herdr";

function items(target) {
  const term = terminals().find((t) => t.address === target.terminal);
  const parent = term?.parent && terminals().find((t) => t.address === term.parent);
  const inTab = panes().some((pane) => pane.pane === target.pane);
  const toProgram = term?.labels?.["herdr.right-click"] === "program";
  return [
    ...(inTab ? [
      ["Split right", "pane.split", { direction: "right", pane: target.pane }],
      ["Split down", "pane.split", { direction: "down", pane: target.pane }],
      ["Zoom", "pane.zoom", { pane: target.pane }],
    ] : []),
    ...(term ? [[toProgram ? "Use Herdr right-click menu" : "Send right-clicks to pane", "terminal.right_click", { terminal: term.address, to: toProgram ? "menu" : "program" }]] : []),
    ...(parent ? [[`Send back to ${parent.name || parent.address}`, "terminal.park", { terminal: term.address }]] : []),
    ...(inTab ? [["Close pane", "pane.close", { pane: target.pane }]] : []),
  ];
}

function shortcut(name, args) {
  const value = Object.values(args)[0];
  return keys().find((key) => key.section === "global" && (key.action === name || key.action === `${name}:${value}`))?.keys ?? "";
}

export default class Menu extends View {
  init(_props, cx) {
    this.at = 0;
    this.handle = cx.focus_handle();
    this.handle.focus();
  }

  choose(item) {
    if (!item) return;
    closeOverlay(props().overlay);
    run(item[1], item[2]);
  }

  render() {
    const list = items(props()?.target ?? {});
    return v_flex().id("menu").track_focus(this.handle).w_full().p(2)
      .bg("#c0c0c0").border(1).border_color("#808080")
      .font_family("Pixelated MS Sans Serif").text_size(10).text_color("#000000")
      .on_key_down((e, cx) => {
        if (e.key === "down") this.at = (this.at + 1) % list.length;
        else if (e.key === "up") this.at = (this.at + list.length - 1) % list.length;
        else if (e.key === "enter") this.choose(list[this.at]);
        else if (e.key === "escape") closeOverlay(props().overlay);
        else return;
        cx.notify();
      })
      .children(list.map((item, i) => v_flex()
        .when(item[1] === "pane.close", (el) => el.child(div().mx(3).my(2).h(1).bg("#808080")))
        .child(h_flex().id(`mi-${i}`).h(21).px(5).gap(8).items_center()
          .when(i === this.at, (el) => el.bg("#000080").text_color("#ffffff"))
          .hover((s) => s.bg("#000080").text_color("#ffffff"))
          .on_click(() => this.choose(item))
          .child(div().flex_1().child(item[0]))
          .child(div().text_size(9).child(shortcut(item[1], item[2]))))));
  }
}
