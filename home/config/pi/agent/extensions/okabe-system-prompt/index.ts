import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const extensionDir = path.dirname(fileURLToPath(import.meta.url));
const promptPath = path.join(extensionDir, "okabe-system-prompt.md");

function loadPrompt(): string {
  return readFileSync(promptPath, "utf8").trim();
}

export default function okabeSystemPromptExtension(pi: ExtensionAPI) {
  pi.on("before_agent_start", async (event) => {
    // pi-subagents marks every spawned child process. Those agents supply
    // their own role-specific prompts from ~/.pi/agent/agents.
    if (process.env.PI_SUBAGENT_CHILD === "1") {
      return;
    }

    const prompt = loadPrompt();

    if (!prompt) {
      return;
    }

    return {
      systemPrompt: `${event.systemPrompt}\n\n${prompt}`,
    };
  });
}
