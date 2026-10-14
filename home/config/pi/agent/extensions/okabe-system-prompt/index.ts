import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import type { BeforeAgentStartEvent, ExtensionAPI } from "@earendil-works/pi-coding-agent";

const extensionDir = path.dirname(fileURLToPath(import.meta.url));
const promptPath = path.join(extensionDir, "okabe-system-prompt.md");

function loadPrompt(): string {
  return readFileSync(promptPath, "utf8").trim();
}

export function appendOkabePrompt(event: BeforeAgentStartEvent) {
  // pi-subagents runs children in-process and tags their own role prompts.
  if (event.systemPrompt.includes('<active_agent name="')) {
    return;
  }

  const prompt = loadPrompt();

  if (!prompt) {
    return;
  }

  event.systemPromptOptions.sections.okabe = prompt;
}

export default function okabeSystemPromptExtension(pi: ExtensionAPI) {
  pi.on("before_agent_start", appendOkabePrompt);
}
