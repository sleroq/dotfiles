import { View } from "gpui-kit";
import { props } from "herdr";
import Taskbar from "./taskbar.js";
import Desktop from "./desktop.js";

export default class TetoTaskbar extends View {
  init(p, cx) {
    const role = props()?.role ?? p?.role;
    this.view = role === "desktop" ? new Desktop() : new Taskbar();
    this.view.init(p, cx);
  }

  render(cx) {
    return this.view.render(cx);
  }
}
