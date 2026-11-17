import { View, div, image } from "gpui-kit";
import { h_flex, v_flex } from "gpui-base";
import { closeOverlay, props, run } from "herdr";

export default class Toast extends View {
  render() {
    const p = props() ?? {};
    const login = /^([a-z0-9][a-z0-9_.-]{0,31}) needs login; run hc machine login \1$/.exec(p.body ?? "");
    const command = login ? `hc machine login ${login[1]}` : null;
    return v_flex().id("toast").size_full().p(8).gap(4)
      .bg("#ffffe1").border(1).border_color("#000000").rounded(8)
      .font_family("Pixelated MS Sans Serif").text_size(11).text_color("#000000")
      .cursor_pointer()
      .on_click(() => {
        if (p.action?.name) run(p.action.name, p.action.args ?? {});
        closeOverlay(p.overlay);
      })
      .child(h_flex().items_center().gap(7)
        .child(p.icon ? image(p.icon).size(18).flex_none() : div().size(18).flex_none()
          .rounded(9).bg("#e4f4ff").border(1).border_color("#4096bc")
          .text_color("#0073ad").font_weight(700).text_center().child("i"))
        .child(div().flex_1().min_w(0).truncate().font_weight(700).child(login ? `${login[1]} needs a login` : p.title ?? ""))
        .child(div().id("toast-close").size(18).flex_none().text_center().bg("#c0c0c0")
          .border(1).border_color("#808080").font_weight(700).child("×")
          .on_click((_e, cx) => { cx.stop_propagation(); closeOverlay(p.overlay); })))
      .when(Boolean(p.body), (el) => el.child(h_flex().gap(6).items_center()
        .child(div().flex_1().min_w(0).child(command ?? p.body))
        .when(Boolean(login), (row) => row.child(div().id("toast-login-copy").px(4).bg("#c0c0c0")
          .border(1).border_color("#808080").child(this.copied ? "Copied" : "Copy")
          .on_click((_e, cx) => { cx.stop_propagation(); cx.write_to_clipboard(command); this.copied = true; cx.notify(); })))));
  }
}
