import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { homedir } from "node:os";
import { join } from "node:path";

export default function (pi: ExtensionAPI) {
  pi.on("resources_discover", () => {
    if (process.env.PASEO_AGENT_ID) return { skillPaths: [join(homedir(), ".pi/paseo-skills")] };
  });
}
