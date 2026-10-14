import { afterEach, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, realpathSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { dirname, join, relative } from "node:path";
import type { ExtensionHandler, ToolResultEvent, ToolResultEventResult } from "@earendil-works/pi-coding-agent";
import extension, { type SubdirContextAPI } from "./index";

type StoredEntry = { type: "custom"; customType: string; data: { paths: string[] } };
type HarnessEvent = Partial<ToolResultEvent> & {
  systemPromptOptions?: { contextFiles: { path: string }[] };
};
type HarnessContext = {
  cwd: string;
  hasUI: false;
  sessionManager: { getBranch(): StoredEntry[] };
};
type HarnessHandler = (event: HarnessEvent, ctx: HarnessContext) =>
  void | ToolResultEventResult | Promise<void | ToolResultEventResult>;

const fixtures: string[] = [];
afterEach(() => fixtures.splice(0).forEach((path) => rmSync(path, { recursive: true, force: true })));

function fixture() {
  const cwd = realpathSync(mkdtempSync(join(tmpdir(), "subdir-context-")));
  fixtures.push(cwd);

  const handlers = new Map<string, HarnessHandler>();
  let branch: StoredEntry[] = [];
  const entries: StoredEntry[] = [];
  const pi: SubdirContextAPI = {
    on<E, R>(name: string, handler: ExtensionHandler<E, R>) {
      // SAFETY: Each fixture dispatches only the registered event's consumed fields and context APIs.
      handlers.set(name, handler as HarnessHandler);
      return () => { handlers.delete(name); };
    },
    appendEntry(customType, data) {
      const entry: StoredEntry = { type: "custom", customType, data: { paths: [] } };
      // SAFETY: This owner writes only its { paths: string[] } custom entries, checked on restoration.
      entry.data = data as StoredEntry["data"];
      entries.push(entry);
      branch.push(entry);
    },
  };

  extension(pi);
  const ctx: HarnessContext = { cwd, hasUI: false, sessionManager: { getBranch: () => branch } };
  function emit(name: string, event: HarnessEvent = {}) {
    return handlers.get(name)!(event, ctx);
  }
  function file(path: string, text = path) {
    const full = join(cwd, path);
    mkdirSync(dirname(full), { recursive: true });
    writeFileSync(full, text);
    return full;
  }

  const content: ToolResultEvent["content"] = [{ type: "text", text: "original" }, { type: "image", data: "image", mimeType: "image/png" }];
  const details = { truncation: undefined };
  async function read(path: string, extra: Partial<ToolResultEvent> = {}) {
    return emit("tool_result", {
      type: "tool_result", toolCallId: "read", toolName: "read", input: { path },
      content, details, isError: false, parentToolCallId: "codemode", ...extra,
    });
  }
  function setBranch(next: StoredEntry[]) { branch = next; }
  return { cwd, file, read, emit, content, details, entries, branch: setBranch };
}

test("parallel nested reads append once, preserve output, and honor hierarchy/override order", async () => {
  const f = fixture();
  f.file("AGENTS.md", "ROOT");
  f.file("a/AGENTS.md", "OUTER");
  f.file("a/b/AGENTS.override.md", "INNER OVERRIDE");
  f.file("a/b/AGENTS.md", "WRONG");
  f.file("a/b/code.ts");
  const results = await Promise.all([f.read("a/b/code.ts"), f.read("a/b/code.ts")]);
  const result = results.find(Boolean);
  expect(results.filter(Boolean)).toHaveLength(1);
  if (!result?.content) throw new Error("Expected injected content");
  expect(result.content.slice(0, 2)).toEqual(f.content);
  expect(result.details).toBe(f.details);
  expect(result.content.slice(2).map((block) => block.type === "text" ? block.text.split("\n\n")[1] : "image")).toEqual(["OUTER", "INNER OVERRIDE"]);
  expect(f.entries).toHaveLength(1);
  expect(f.entries[0].data.paths).toHaveLength(2);
});

test("ignores root/global/outside targets and unsuccessful or unrelated tools", async () => {
  const f = fixture();
  const outside = fixture();
  f.file("AGENTS.md");
  f.file("code.ts");
  outside.file("child/AGENTS.md");
  const target = outside.file("child/code.ts");
  symlinkSync(dirname(target), join(f.cwd, "outside"));
  expect(await f.read("code.ts")).toBeUndefined();
  expect(await f.read(target)).toBeUndefined();
  expect(await f.read("outside/code.ts")).toBeUndefined();
  f.file("a/AGENTS.md");
  f.file("a/code.ts");
  expect(await f.read("a/code.ts", { isError: true })).toBeUndefined();
  expect(await f.read("a/code.ts", { toolName: "bash" })).toBeUndefined();
  expect(f.entries).toHaveLength(0);
});

test("canonical aliases, explicit instruction reads, and native seeds deduplicate", async () => {
  const f = fixture();
  const instruction = f.file("a/AGENTS.md");
  f.file("a/code.ts");
  symlinkSync(join(f.cwd, "a"), join(f.cwd, "alias"));
  expect(await f.read("alias/AGENTS.md")).toBeUndefined();
  expect(await f.read("a/code.ts")).toBeUndefined();
  expect(f.entries[0].data.paths).toEqual([instruction]);
  await f.emit("session_start");
  expect(await f.read("alias/code.ts")).toBeUndefined();
  f.branch([]);
  await f.emit("session_start");
  f.emit("before_agent_start", { systemPromptOptions: { contextFiles: [{ path: instruction }] } });
  expect(await f.read("a/code.ts")).toBeUndefined();
  expect(f.entries).toHaveLength(1);
});

test("reload restores only custom state on the active branch; switching drops abandoned state", async () => {
  const f = fixture();
  f.file("a/AGENTS.md");
  f.file("a/code.ts");
  f.file("b/AGENTS.md");
  f.file("b/code.ts");
  await f.read("a/code.ts");
  const shared = [...f.entries];
  await f.read("b/code.ts");
  await f.emit("session_start");
  expect(await f.read("a/code.ts")).toBeUndefined();
  expect(await f.read("b/code.ts")).toBeUndefined();
  f.branch([...shared, { type: "custom", customType: "other", data: { paths: [join(f.cwd, "b/AGENTS.md")] } }]);
  await f.emit("session_tree");
  expect(await f.read("a/code.ts")).toBeUndefined();
  expect((await f.read("b/code.ts"))?.content).toHaveLength(3);
});


test("expands native ~/ read paths before applying the project boundary", async () => {
  const f = fixture();
  f.file("a/AGENTS.md");
  const target = f.file("a/code.ts");
  expect((await f.read(`~/${relative(homedir(), target)}`))?.content).toHaveLength(3);
});
