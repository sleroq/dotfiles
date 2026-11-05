import { z } from "zod";
import type { CacheMiss } from "../shared/cache-miss.ts";

const entrySchema = z.object({
  type: z.string(),
  id: z.string(),
  parentId: z.string().nullable(),
  timestamp: z.iso.datetime(),
  message: z.unknown().optional(),
});
const assistantSchema = z.object({
  role: z.literal("assistant"),
  api: z.string(),
  provider: z.string(),
  model: z.string(),
  stopReason: z.string(),
  usage: z.object({
    input: z.number().nonnegative(),
    cacheRead: z.number().nonnegative(),
    cacheWrite: z.number().nonnegative(),
  }),
});

type Request = z.infer<typeof assistantSchema>;

function activeBranch(entries: z.infer<typeof entrySchema>[]) {
  let parentId = entries.at(-1)?.id ?? null;
  const branch: typeof entries = [];
  for (const entry of entries.toReversed()) {
    if (entry.id !== parentId) continue;
    branch.push(entry);
    parentId = entry.parentId;
  }
  if (parentId !== null) throw new Error("Pi transcript has a missing ancestor");
  return branch.reverse();
}

export function findCacheMisses(contents: string, since: number) {
  const lines = contents.trim().split("\n");
  const header = z.object({ type: z.literal("session"), version: z.literal(3), id: z.string() })
    .parse(JSON.parse(lines.shift()!));
  const entries = lines.filter((line) => line.trim()).map((line) => entrySchema.parse(JSON.parse(line)));
  const misses: { id: string; data: CacheMiss }[] = [];
  let previous: Request | undefined;

  for (const entry of activeBranch(entries)) {
    // These operations intentionally replace the prompt prefix.
    if (["compaction", "branch_summary", "context_edit", "model_change"].includes(entry.type)) {
      previous = undefined;
    }
    if (entry.type !== "message") continue;
    const parsed = assistantSchema.safeParse(entry.message);
    if (!parsed.success) continue;
    const request = parsed.data;
    if (["error", "aborted"].includes(request.stopReason)) continue;
    const { input, cacheRead, cacheWrite } = request.usage;
    const promptTokens = input + cacheRead + cacheWrite;
    if (!promptTokens) continue;
    const previousCached = previous ? previous.usage.cacheRead + previous.usage.cacheWrite : 0;
    // Entry time is persistence time; message time predates the asynchronous turn-start hook.
    if (
      previous && Date.parse(entry.timestamp) >= since &&
      request.api === previous.api && request.provider === previous.provider && request.model === previous.model &&
      previousCached - cacheRead >= 1024 && cacheRead < previousCached * 0.8
    ) {
      misses.push({
        id: `${header.id}:${entry.id}`,
        data: { model: `${request.provider}/${request.model}`, cacheRead, previousCached, promptTokens },
      });
    }
    previous = request;
  }
  return misses;
}
