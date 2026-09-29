import { afterEach, beforeAll, beforeEach, expect, mock, test } from "bun:test";
import { existsSync, mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext, McpServerConfig } from "@earendil-works/pi-coding-agent";

const decisions = new Map<string, boolean>();
let agentDir: string;
let packageDir: string;
const originalArgv = [...process.argv];
mock.module("@earendil-works/pi-coding-agent", () => ({
  getAgentDir: () => agentDir,
  getPackageDir: () => packageDir,
  hasTrustRequiringProjectResources: (cwd: string) => existsSync(join(cwd, ".pi", "settings.json")) || existsSync(join(cwd, ".pi", "mcp.json")),
  ProjectTrustStore: class {
    get(cwd: string) { return decisions.get(cwd) ?? null; }
    set(cwd: string, decision: boolean) { decisions.set(cwd, decision); }
  },
}));

let extension: typeof import("./index").default;
beforeAll(async () => { extension = (await import("./index")).default; });

let root: string;
let cwd: string;
let registrations: Map<string, McpServerConfig>;
let warnings: string[];
let confirms: Array<[string, string]>;
let handler: (event: unknown, ctx: ExtensionContext) => Promise<void>;
let confirmResult: boolean;
let trusted: boolean;
let hasUI: boolean;
let mode: ExtensionContext["mode"];
let removed: string[];

beforeEach(() => {
  root = mkdtempSync(join(tmpdir(), "pi-opencode-mcp-"));
  agentDir = join(root, "agent");
  packageDir = join(root, "fake-package");
  process.env.PI_CODING_AGENT_DIR = agentDir;
  cwd = join(root, "project");
  mkdirSync(cwd);
  decisions.clear();
  registrations = new Map();
  warnings = [];
  confirms = [];
  removed = [];
  confirmResult = true;
  trusted = true;
  hasUI = true;
  mode = "tui";
  extension({
    on: (_name: string, callback: typeof handler) => { handler = callback; return () => {}; },
    registerMcpServer: (name: string, config: McpServerConfig) => {
      if (!/^[a-zA-Z0-9_-]+$/.test(name)) throw new Error("invalid native name");
      registrations.set(name, config);
    },
    unregisterMcpServer: (name: string) => { removed.push(name); registrations.delete(name); },
  } as unknown as ExtensionAPI);
});
afterEach(() => {
  process.argv.splice(0, process.argv.length, ...originalArgv);
  delete process.env.PI_CODING_AGENT_DIR;
  rmSync(root, { recursive: true, force: true });
});

function putConfig(value: unknown) {
  writeFileSync(join(cwd, "opencode.json"), JSON.stringify(value));
}
function nativeFile(content: string) {
  mkdirSync(join(cwd, ".pi"), { recursive: true });
  writeFileSync(join(cwd, ".pi", "mcp.json"), content);
}
async function start() {
  await handler({}, {
    cwd, hasUI, mode,
    isProjectTrusted: () => trusted,
    ui: {
      notify: (message: string) => warnings.push(message),
      confirm: async (title: string, message: string) => { confirms.push([title, message]); return confirmResult; },
    },
  } as unknown as ExtensionContext);
}

const fixture = {
  mcp: { servers: {
    datagrip: {
      type: "remote", url: "http://127.0.0.1:64402/stream", oauth: false,
      headers: { IJ_MCP_SERVER_PROJECT_PATH: "/Users/sleroq/DataGripProjects/am" },
    },
    playwright: {
      type: "local", command: ["direnv", "exec", ".", "./scripts/playwright-mcp.sh"],
      environment: { PLAYWRIGHT_USE_PROXY: "1" }, timeout: { startup: 120000 },
    },
  } },
};

test("imports both fixture servers through session registrations, with timeout and OAuth warnings", async () => {
  putConfig(fixture);
  await start();
  expect([...registrations]).toEqual([
    ["datagrip", { url: "http://127.0.0.1:64402/stream", headers: { IJ_MCP_SERVER_PROJECT_PATH: "/Users/sleroq/DataGripProjects/am" } }],
    ["playwright", { command: "direnv", args: ["exec", ".", "./scripts/playwright-mcp.sh"], env: { PLAYWRIGHT_USE_PROXY: "1" }, timeout: 120 }],
  ]);
  expect(warnings.join(" ")).toContain("oauth:false");
  expect(warnings.join(" ")).toContain("all requests");
  expect(confirms).toHaveLength(1);
  expect(confirms[0]![0]).toBe("Trust this project folder?");
  expect(confirms[0]![1]).toContain("all Pi project settings and resources");
  expect(decisions.get(cwd)).toBe(true);
  expect(existsSync(join(cwd, ".pi", "mcp.json"))).toBe(false);
  expect(existsSync(agentDir)).toBe(false);
});

test.each(["{}", "not json"])("project native MCP file takes precedence even if %s", async (content) => {
  putConfig(fixture);
  nativeFile(content);
  await start();
  expect(registrations.size).toBe(0);
  expect(confirms).toHaveLength(0);
});

test("untrusted and bare unapproved projects do not read or register config", async () => {
  writeFileSync(join(cwd, "opencode.json"), "invalid JSON");
  trusted = false;
  await start();
  expect(registrations.size).toBe(0);
  expect(confirms).toHaveLength(0);
  expect(warnings).toEqual([]);
  trusted = true;
  putConfig(fixture);
  hasUI = false;
  await start();
  expect(registrations.size).toBe(0);
  expect(warnings.join(" ")).toContain("/trust");
  hasUI = true;
  confirmResult = false;
  await start();
  expect(registrations.size).toBe(0);
  expect(decisions.size).toBe(0);
  await start();
  expect(confirms).toHaveLength(1);
  decisions.set(cwd, false);
  writeFileSync(join(cwd, "opencode.json"), "invalid JSON");
  confirmResult = true;
  await start();
  expect(registrations.size).toBe(0);
  expect(confirms).toHaveLength(1);
  expect(warnings.join(" ")).not.toContain("invalid JSON");
});

test.each([{}, { mcp: { servers: {} } }])("does not request project trust when no MCP servers exist: %j", async (config) => {
  putConfig(config);
  await start();
  expect(confirms).toHaveLength(0);
  expect(decisions.size).toBe(0);
  expect(registrations.size).toBe(0);
  expect(warnings).toEqual([]);
});

test("RPC startup skips unapproved imports without blocking on a dialog", async () => {
  putConfig(fixture);
  mode = "rpc";
  hasUI = true;
  await start();
  expect(confirms).toHaveLength(0);
  expect(registrations.size).toBe(0);
  expect(warnings.join(" ")).toContain("/trust");
});

test("saved trust or native-protected resources permit import without another prompt", async () => {
  putConfig(fixture);
  decisions.set(cwd, true);
  await start();
  expect(registrations.size).toBe(2);
  expect(confirms).toHaveLength(0);
  decisions.clear();
  registrations.clear();
  mkdirSync(join(cwd, ".pi"));
  writeFileSync(join(cwd, ".pi", "settings.json"), "{}");
  await start();
  expect(registrations.size).toBe(2);
  expect(confirms).toHaveLength(0);
});

test("Pi CLI --approve overrides saved denial for this run; SDK -a cannot", async () => {
  putConfig(fixture);
  decisions.set(cwd, false);
  hasUI = false;
  process.argv.push("-a");
  await start();
  expect(registrations.size).toBe(0);

  mkdirSync(join(packageDir, "dist", "bundle"), { recursive: true });
  process.argv[1] = join(packageDir, "dist", "bundle", "cli.js");
  writeFileSync(process.argv[1], "");
  await start();
  expect(registrations.size).toBe(2);
  expect(decisions.get(cwd)).toBe(false);
  expect(confirms).toHaveLength(0);
});

test("global native MCP file does not block project fallback", async () => {
  mkdirSync(agentDir);
  writeFileSync(join(agentDir, "mcp.json"), "{}");
  putConfig(fixture);
  decisions.set(cwd, true);
  await start();
  expect(registrations.size).toBe(2);
  expect(readFileSync(join(agentDir, "mcp.json"), "utf8")).toBe("{}");
});

test("resolves command/url/cwd env eagerly and leaves native env/header/clientSecret references", async () => {
  process.env.OPENCODE_MCP_TEST = "resolved";
  putConfig({ mcp: { servers: {
    local: { type: "local", command: ["{env:OPENCODE_MCP_TEST}", "{env:OPENCODE_MCP_TEST}"], cwd: "{env:OPENCODE_MCP_TEST}", environment: { X: "{env:OPENCODE_MCP_TEST}" }, enabled: false, timeout: 1000 },
    remote: { type: "remote", url: "https://{env:OPENCODE_MCP_TEST}/mcp", headers: { X: "{env:OPENCODE_MCP_TEST}" }, oauth: { clientId: "client", clientSecret: "{env:OPENCODE_MCP_TEST}", scope: "read", callbackPort: 8765 } },
  } } });
  await start();
  expect(registrations.get("local")).toEqual({ command: "resolved", args: ["resolved"], cwd: "resolved", env: { X: "${OPENCODE_MCP_TEST}" }, enabled: false, timeout: 1 });
  expect(registrations.get("remote")).toEqual({ url: "https://resolved/mcp", headers: { X: "${OPENCODE_MCP_TEST}" }, oauth: { clientId: "client", clientSecret: "${OPENCODE_MCP_TEST}", scope: "read", callbackPort: 8765 } });
  delete process.env.OPENCODE_MCP_TEST;
});

test("invalid JSON, shape, and individual servers warn without blocking valid entries", async () => {
  writeFileSync(join(cwd, "opencode.json"), "{ invalid");
  await start();
  expect(warnings.join(" ")).toContain("invalid JSON");
  warnings.length = 0;
  putConfig({});
  await start();
  expect(warnings).toEqual([]);
  putConfig({ mcp: [] });
  await start();
  expect(warnings.join(" ")).toContain("mcp.servers");
  warnings.length = 0;
  putConfig({ mcp: { servers: {
    bad: { type: "local", command: ["{env:OPENCODE_MCP_MISSING}"] },
    "bad name": { type: "local", command: ["node"] },
    good: { type: "remote", url: "https://example.com/mcp", timeout: { startup: 2000, request: 3000 } },
  } } });
  await start();
  expect(registrations.get("good")).toEqual({ url: "https://example.com/mcp", timeout: 3 });
  expect(warnings.join(" ")).toContain("missing environment variable OPENCODE_MCP_MISSING");
  expect(warnings.join(" ")).toContain("bad name");
  expect(warnings.join(" ")).toContain("all requests");
});

test("removes only its prior registrations when a native file appears or cwd changes", async () => {
  putConfig(fixture);
  decisions.set(cwd, true);
  await start();
  nativeFile("{}");
  await start();
  expect(removed).toEqual(["datagrip", "playwright"]);
  expect(registrations.size).toBe(0);
  rmSync(join(cwd, ".pi", "mcp.json"));
  await start();
  const previous = cwd;
  cwd = join(root, "next");
  mkdirSync(cwd);
  putConfig({ mcp: { servers: { next: { type: "remote", url: "https://example.com/mcp" } } } });
  decisions.set(cwd, true);
  await start();
  expect(registrations.has("datagrip")).toBe(false);
  expect(registrations.has("next")).toBe(true);
  expect(readFileSync(join(previous, "opencode.json"), "utf8")).toBe(JSON.stringify(fixture));
});
