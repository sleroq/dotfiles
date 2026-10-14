import { isReadToolResult } from "@earendil-works/pi-coding-agent";
import type { ExtensionAPI, ExtensionContext, ReadToolInput, SessionStartEvent, SessionTreeEvent } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { Check } from "typebox/value";
import { homedir } from "node:os";
import { existsSync, realpathSync } from "node:fs";
import { readFile } from "node:fs/promises";
import { basename, dirname, isAbsolute, join, relative, resolve } from "node:path";

export type SubdirContextAPI = Pick<ExtensionAPI, "on" | "appendEntry">;
const loadedPaths = Type.Object({ paths: Type.Array(Type.String()) });
const names = ["AGENTS.override.md", "AGENTS.md", "AGENTS.MD", "CLAUDE.md", "CLAUDE.MD"];

function canonical(path: string): string | undefined {
  try {
    return realpathSync(path);
  } catch {
    return undefined;
  }
}

function nestedInstructions(root: string, file: string): string[] {
  const directories: string[] = [];
  for (let directory = dirname(file); directory !== root; directory = dirname(directory)) {
    directories.unshift(directory);
  }
  return directories.flatMap((directory) => {
    const candidate = names.map((name) => join(directory, name)).find(existsSync);
    const path = candidate && canonical(candidate);
    if (!path) return [];
    const location = relative(root, path);
    return location && location !== ".." && !location.startsWith("../") && !isAbsolute(location) ? [path] : [];
  });
}

export default function subdirContext(pi: SubdirContextAPI) {
  let loaded = new Set<string>();

  function restore(_event: SessionStartEvent | SessionTreeEvent, ctx: ExtensionContext) {
    loaded = new Set<string>();
    for (const entry of ctx.sessionManager.getBranch()) {
      if (entry.type !== "custom" || entry.customType !== "subdir-context") continue;
      if (!Check(loadedPaths, entry.data)) continue;
      for (const path of entry.data.paths) {
        const key = canonical(path);
        if (key) loaded.add(key);
      }
    }
  }
  pi.on("session_start", restore);
  pi.on("session_tree", restore);
  pi.on("before_agent_start", (event) => {
    for (const file of event.systemPromptOptions.contextFiles) {
      const key = canonical(file.path);
      if (key) loaded.add(key);
    }
  });

  pi.on("tool_result", async (event, ctx) => {
    if (!isReadToolResult(event) || event.isError) return;
    // SAFETY: Pi validates the native read arguments before emitting a successful result.
    const input = event.input as ReadToolInput;
    const path = input.path.startsWith("~/") ? join(homedir(), input.path.slice(2)) : input.path;
    const root = canonical(ctx.cwd);
    const file = canonical(resolve(ctx.cwd, path));
    if (!root || !file) return;
    const location = relative(root, file);
    if (!location || location === ".." || location.startsWith("../") || isAbsolute(location)) return;

    const paths: string[] = [];
    if (names.includes(basename(file)) && !loaded.has(file)) {
      loaded.add(file);
      paths.push(file);
    }
    const pending = nestedInstructions(root, file).filter((path) => {
      if (loaded.has(path)) return false;
      loaded.add(path);
      return true;
    });
    const content = [...event.content];
    for (const path of pending) {
      try {
        const instructions = await readFile(path, "utf8");
        content.push({ type: "text", text: `Loaded subdirectory context from ${path}\n\n${instructions}` });
        paths.push(path);
      } catch (error) {
        loaded.delete(path);
        if (ctx.hasUI) ctx.ui.notify(`Could not read ${path}: ${error}`, "warning");
      }
    }
    if (paths.length) pi.appendEntry("subdir-context", { paths });
    if (content.length !== event.content.length) return { content, details: event.details };
  });
}
