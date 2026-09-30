import { spawn } from "node:child_process";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.on("agent_settled", (_event, ctx) => {
    if (ctx.mode !== "tui") return;

    const command = process.env.PI_MAIN_NOTIFY_SOUND_CMD?.trim();
    if (!command) return;

    const child = spawn(command, {
      shell: true,
      detached: true,
      stdio: "ignore",
    });
    child.unref();
  });
}
