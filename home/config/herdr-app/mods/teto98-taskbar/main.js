import { View } from "gpui-kit";
import Taskbar from "./taskbar.js";

export default class TetoTaskbar extends View {
  init(p, cx) {
    this.taskbar = new Taskbar();
    this.taskbar.init(p, cx);
  }

  render(cx) {
    return this.taskbar.render(cx);
  }
}
