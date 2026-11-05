import { readFile } from "node:fs/promises";
import type { PaseoAgentHandle } from "@getpaseo/client";
import { findCacheMisses } from "./transcript.ts";

export async function publishCacheMisses(agent: PaseoAgentHandle, since: number) {
  const snapshot = await agent.refresh();
  const path = snapshot?.agent.persistence?.nativeHandle;
  if (!path) return;
  const contents = await readFile(path, "utf8");
  for (const miss of findCacheMisses(contents, since)) {
    await agent.timeline.append({ type: "plugin", kind: "cache-miss", version: 1, ...miss });
  }
}
