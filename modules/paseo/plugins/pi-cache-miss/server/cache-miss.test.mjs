import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import contribute from "../index.server.ts";
import { publishCacheMisses } from "./monitor.ts";
import { findCacheMisses } from "./transcript.ts";

function assistant(id, cacheRead, options = {}) {
  return {
    type: "message", id, parentId: null,
    message: {
      role: "assistant", api: "openai-responses", provider: "fumo", model: "codex/gpt-6.1-sol",
      timestamp: 1000, stopReason: "toolUse",
      usage: { input: 100, cacheRead, cacheWrite: 0 },
      ...options,
    },
  };
}

function transcript(...entries) {
  return [
    { type: "session", version: 3, id: "session" },
    ...entries.map((entry, index) => ({
      timestamp: new Date(entry.message?.timestamp ?? 1000).toISOString(),
      ...entry, parentId: entries[index - 1]?.id ?? null,
    })),
  ].map(JSON.stringify).join("\n") + "\n";
}

function misses(...entries) {
  return findCacheMisses(transcript(...entries), 100);
}

const warm = () => assistant("warm", 10000, { timestamp: 1 });

for (const [name, entries] of [
  ["cold start", [assistant("cold", 0)]],
  ["provider without reported caching", [assistant("a", 0), assistant("b", 0)]],
  ["normal incremental prompt growth", [warm(), assistant("next", 10000)]],
  ["large new uncached input", [warm(), assistant("next", 10000, { usage: { input: 90000, cacheRead: 10000, cacheWrite: 0 } })]],
  ["retention at exactly 80%", [warm(), assistant("next", 8000)]],
  ["drop smaller than 1024 tokens", [assistant("a", 2000), assistant("b", 1000)]],
  ["API change", [warm(), assistant("next", 0, { api: "anthropic-messages" })]],
  ["provider change", [warm(), assistant("next", 0, { provider: "other" })]],
  ["model change", [warm(), assistant("next", 0, { model: "other" })]],
  ["aborted request", [warm(), assistant("next", 0, { stopReason: "aborted" })]],
  ["errored request", [warm(), assistant("next", 0, { stopReason: "error" })]],
]) {
  test(`does not warn for ${name}`, () => assert.deepEqual(misses(...entries), []));
}

for (const type of ["compaction", "branch_summary", "context_edit", "model_change"]) {
  test(`resets the baseline after ${type}`, () => {
    assert.deepEqual(misses(warm(), { type, id: "reset" }, assistant("next", 0)), []);
  });
}

test("warns on a full cache miss with model and request-level counts", () => {
  assert.deepEqual(misses(warm(), assistant("miss", 0)), [{
    id: "session:miss",
    data: { model: "fumo/codex/gpt-6.1-sol", cacheRead: 0, previousCached: 10000, promptTokens: 100 },
  }]);
});

test("warns on a partial prefix loss, including the 1024-token boundary", () => {
  assert.equal(misses(assistant("a", 4096), assistant("b", 3072)).length, 1);
});

test("uses cache writes as evidence of a previously cached prefix", () => {
  const written = assistant("write", 0, { usage: { input: 100, cacheRead: 0, cacheWrite: 10000 } });
  const [miss] = misses(written, assistant("next", 0));
  assert.equal(miss.data.previousCached, 10000);
});

test("includes read and write tokens in the current prompt size", () => {
  const [miss] = misses(warm(), assistant("next", 1000, { usage: { input: 500, cacheRead: 1000, cacheWrite: 2000 } }));
  assert.equal(miss.data.promptTokens, 3500);
});

test("keeps a miss visible even when a later request in the turn hits", () => {
  const entries = [warm(), assistant("miss", 0), assistant("recovered", 10000)];
  assert.deepEqual(misses(...entries).map(({ id }) => id), ["session:miss"]);
});

test("ignores earlier turns but uses them to establish the baseline", () => {
  assert.deepEqual(findCacheMisses(transcript(warm(), assistant("old-miss", 0, { timestamp: 50 })), 100), []);
  assert.equal(findCacheMisses(transcript(warm(), assistant("new-miss", 0)), 1000).length, 1);
});

test("uses persistence time, not request-start time, for the asynchronous turn boundary", () => {
  const request = assistant("miss", 0, { timestamp: 50 });
  request.timestamp = new Date(1000).toISOString();
  assert.equal(misses(warm(), request).length, 1);
});

test("preserves the baseline across user prompts, tools, and failed zero-usage calls", () => {
  const entries = [
    warm(),
    { type: "message", id: "tool", message: { role: "toolResult" } },
    { type: "message", id: "user", message: { role: "user", content: "Continue" } },
    assistant("error", 0, { stopReason: "error" }),
    assistant("miss", 0),
  ];
  assert.deepEqual(misses(...entries).map(({ id }) => id), ["session:miss"]);
});

test("compares the active ancestry, not the abandoned branch", () => {
  const contents = transcript(warm(), assistant("abandoned", 100000), assistant("active", 10000))
    .replace('"id":"active","parentId":"abandoned"', '"id":"active","parentId":"warm"');
  assert.deepEqual(findCacheMisses(contents, 100), []);
});

test("does not emit misses from an abandoned branch", () => {
  const contents = transcript(warm(), assistant("abandoned-miss", 0), assistant("active", 10000))
    .replace('"id":"active","parentId":"abandoned-miss"', '"id":"active","parentId":"warm"');
  assert.deepEqual(findCacheMisses(contents, 100), []);
});

test("rejects malformed JSON and broken ancestry rather than inventing counts", () => {
  assert.throws(() => findCacheMisses("not json", 100));
  const broken = transcript(warm()).replace('"parentId":null', '"parentId":"missing"');
  assert.throws(() => findCacheMisses(broken, 100), /missing ancestor/);
});

async function sessionFile(t, contents) {
  const directory = await mkdtemp(join(tmpdir(), "pi-cache-miss-"));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const path = join(directory, "custom-location.jsonl");
  await writeFile(path, contents);
  return path;
}

function agentHandle(path) {
  const rows = [];
  let refreshes = 0;
  return {
    rows,
    get refreshes() { return refreshes; },
    async refresh() {
      refreshes++;
      return { agent: { persistence: path ? { nativeHandle: path } : null } };
    },
    timeline: { async append(row) { rows.push(row); } },
  };
}

test("reads the exact persisted file, publishes stable IDs, and leaves Pi untouched", async (t) => {
  const contents = transcript(warm(), assistant("miss", 0));
  const path = await sessionFile(t, contents);
  const agent = agentHandle(path);
  await publishCacheMisses(agent, 100);
  await publishCacheMisses(agent, 100);
  assert.equal(agent.rows.length, 2);
  assert.deepEqual(agent.rows[0], agent.rows[1]);
  assert.equal(agent.rows[0].type, "plugin");
  assert.equal(agent.rows[0].kind, "cache-miss");
  assert.equal(agent.rows[0].version, 1);
  assert.equal(await readFile(path, "utf8"), contents);
});

test("ignores ephemeral or not-yet-persisted sessions", async () => {
  const agent = agentHandle(null);
  await publishCacheMisses(agent, 100);
  assert.deepEqual(agent.rows, []);
});

test("surfaces file errors to Paseo's hook error reporting", async () => {
  const agent = agentHandle("/no-such-pi-session.jsonl");
  await assert.rejects(() => publishCacheMisses(agent, 100), { code: "ENOENT" });
});

for (const kind of ["completed", "failed", "canceled"]) {
  test(`hooks inspect ${kind} Pi turns and clean up on stop`, async (t) => {
    t.mock.method(Date, "now", () => 100);
    const path = await sessionFile(t, transcript(warm(), assistant("miss", 0)));
    const agent = agentHandle(path);
    const hooks = new Map();
    const cleanup = contribute({
      addHook(name, handler) { hooks.set(name, handler); return () => hooks.delete(name); },
    });
    const event = { agent: { id: "pi-agent", provider: "pi" }, outcome: { kind } };
    const context = { paseo: { agents: { ref(id) { assert.equal(id, "pi-agent"); return agent; } } } };
    await hooks.get("agent.turn.before")(event);
    await hooks.get("agent.turn.after")(event, context);
    assert.equal(agent.rows.length, 1);
    await hooks.get("agent.turn.after")(event, context);
    assert.equal(agent.refreshes, 1);
    cleanup();
    assert.equal(hooks.size, 0);
  });
}

test("does not inspect other providers or turns already in flight at plugin start", async () => {
  const hooks = new Map();
  const cleanup = contribute({ addHook(name, handler) { hooks.set(name, handler); return () => hooks.delete(name); } });
  const context = { paseo: { agents: { ref() { assert.fail("unexpected agent access"); } } } };
  await hooks.get("agent.turn.after")({ agent: { id: "pi-agent", provider: "pi" } }, context);
  const other = { agent: { id: "codex-agent", provider: "codex" } };
  await hooks.get("agent.turn.before")(other);
  await hooks.get("agent.turn.after")(other, context);
  cleanup();
});
