import { existsSync, readFileSync, realpathSync } from "node:fs";
import { join } from "node:path";
import {
  getAgentDir,
  getPackageDir,
  hasTrustRequiringProjectResources,
  ProjectTrustStore,
  type ExtensionAPI,
  type McpServerConfig,
} from "@earendil-works/pi-coding-agent";

type RecordValue = Record<string, unknown>;

function isRecord(value: unknown): value is RecordValue {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function stringMap(value: unknown, field: string): Record<string, string> {
  if (!isRecord(value)) throw new Error(`${field} must be an object of strings`);
  const result: Record<string, string> = {};
  for (const [key, item] of Object.entries(value)) {
    if (typeof item !== "string") throw new Error(`${field} must be an object of strings`);
    result[key] = item;
  }
  return result;
}

const envReference = /\{env:([A-Za-z_][A-Za-z0-9_]*)\}/g;

function nativeReference(value: string): string {
  return value.replace(envReference, (_match, name: string) => `\${${name}}`);
}

function resolvedReference(value: string): string {
  return value.replace(envReference, (_match, name: string) => {
    const resolved = process.env[name];
    if (resolved === undefined) throw new Error(`missing environment variable ${name}`);
    return resolved;
  });
}

function convertTimeout(value: unknown, warn: (message: string) => void): number | undefined {
  if (value === undefined) return undefined;
  if (typeof value === "number") {
    if (!Number.isFinite(value) || value <= 0) throw new Error("timeout must be positive milliseconds");
    return value / 1000;
  }
  if (!isRecord(value)) throw new Error("timeout must be milliseconds or an object");
  const { startup, request } = value;
  for (const [field, duration] of Object.entries({ startup, request })) {
    if (duration !== undefined && (typeof duration !== "number" || !Number.isFinite(duration) || duration <= 0)) {
      throw new Error(`timeout.${field} must be positive milliseconds`);
    }
  }
  if (startup !== undefined) warn("startup timeout applies to all requests in Pi, not just startup");
  const durations = [startup, request].filter((duration): duration is number => typeof duration === "number");
  return durations.length ? Math.max(...durations) / 1000 : undefined;
}

function convertServer(value: unknown, warn: (message: string) => void): McpServerConfig {
  if (!isRecord(value)) throw new Error("server must be an object");
  const { type, enabled } = value;
  if (enabled !== undefined && typeof enabled !== "boolean") throw new Error("enabled must be a boolean");
  const timeout = convertTimeout(value.timeout, warn);
  const common: { enabled?: boolean; timeout?: number } = {};
  if (typeof enabled === "boolean") common.enabled = enabled;
  if (timeout !== undefined) common.timeout = timeout;

  if (type === "local") {
    const command = value.command;
    if (!Array.isArray(command) || !command.length || command.some((part) => typeof part !== "string") || !command[0]) {
      throw new Error("local command must be a nonempty string array");
    }
    const env = value.environment === undefined ? undefined : Object.fromEntries(
      Object.entries(stringMap(value.environment, "environment")).map(([key, item]) => [key, nativeReference(item)]),
    );
    const cwd = value.cwd;
    if (cwd !== undefined && typeof cwd !== "string") throw new Error("cwd must be a string");
    const config: McpServerConfig = {
      ...common,
      command: resolvedReference(command[0]),
      args: command.slice(1).map(resolvedReference),
    };
    if (env !== undefined) config.env = env;
    if (typeof cwd === "string") config.cwd = resolvedReference(cwd);
    return config;
  }

  if (type === "remote") {
    if (typeof value.url !== "string" || !value.url) throw new Error("remote url must be a nonempty string");
    const headers = value.headers === undefined ? undefined : Object.fromEntries(
      Object.entries(stringMap(value.headers, "headers")).map(([key, item]) => [key, nativeReference(item)]),
    );
    const oauth = value.oauth;
    if (oauth === false) warn("oauth:false cannot be disabled in Pi; native OAuth is offered on 401 (no Authorization header added)");
    let nativeOAuth: Extract<McpServerConfig, { url: string }>["oauth"];
    if (oauth !== undefined && oauth !== true && oauth !== false) {
      if (!isRecord(oauth)) throw new Error("oauth must be a boolean or object");
      nativeOAuth = {};
      for (const field of ["clientId", "clientSecret", "scope", "callbackUrl"] as const) {
        const item = oauth[field];
        if (item !== undefined) {
          if (typeof item !== "string") throw new Error(`oauth.${field} must be a string`);
          nativeOAuth[field] = field === "clientSecret" ? nativeReference(item) : item;
        }
      }
      if (oauth.callbackPort !== undefined) {
        if (typeof oauth.callbackPort !== "number" || !Number.isInteger(oauth.callbackPort) || oauth.callbackPort <= 0) {
          throw new Error("oauth.callbackPort must be a positive integer");
        }
        nativeOAuth.callbackPort = oauth.callbackPort;
      }
    }
    const config: McpServerConfig = { ...common, url: resolvedReference(value.url) };
    if (headers !== undefined) config.headers = headers;
    if (nativeOAuth !== undefined) config.oauth = nativeOAuth;
    return config;
  }
  throw new Error("type must be local or remote");
}

// Only the installed Pi CLI's explicit approval flag can bypass a bare directory's absent trust decision.
function cliApproved(): boolean {
  const entry = process.argv[1];
  if (!entry || !process.argv.slice(2).some((arg) => arg === "--approve" || arg === "-a")) return false;
  try {
    return realpathSync(entry) === realpathSync(join(getPackageDir(), "dist", "bundle", "cli.js"));
  } catch {
    return false;
  }
}

export default function (pi: ExtensionAPI) {
  const registered = new Set<string>();
  let declinedCwd: string | undefined;
  pi.on("session_start", async (_event, ctx) => {
    for (const name of registered) pi.unregisterMcpServer(name);
    registered.clear();
    if (declinedCwd !== ctx.cwd) declinedCwd = undefined;

    if (!ctx.isProjectTrusted()) return;
    const path = join(ctx.cwd, "opencode.json");
    if (existsSync(join(ctx.cwd, ".pi", "mcp.json")) || !existsSync(path)) return;
    function warn(message: string) {
      ctx.ui.notify(`opencode-mcp: ${message}`, "warning");
    }

    let pendingTrust: ProjectTrustStore | undefined;
    if (!hasTrustRequiringProjectResources(ctx.cwd)) {
      try {
        const store = new ProjectTrustStore(getAgentDir());
        const decision = store.get(ctx.cwd);
        if (decision === false && !cliApproved()) return;
        if (decision === null && !cliApproved()) pendingTrust = store;
      } catch (error) {
        warn(`cannot check project trust: ${String(error)}`);
        return;
      }
    }

    let config: unknown;
    try {
      config = JSON.parse(readFileSync(path, "utf8"));
    } catch (error) {
      warn(`invalid JSON in ${path}: ${String(error)}`);
      return;
    }
    if (!isRecord(config)) {
      warn(`${path}: expected an object`);
      return;
    }
    if (!("mcp" in config)) return;
    if (!isRecord(config.mcp) || !isRecord(config.mcp.servers)) {
      warn(`${path}: mcp.servers must be an object`);
      return;
    }
    const servers = Object.entries(config.mcp.servers);
    if (servers.length === 0) return;

    if (pendingTrust) {
      if (declinedCwd === ctx.cwd) return;
      // RPC's input loop is not running during session_start, so it cannot answer a dialog yet.
      const canConfirm = ctx.mode === "tui" && ctx.hasUI;
      if (!canConfirm || !(await ctx.ui.confirm("Trust this project folder?", "Loading opencode.json MCP can execute commands and send configured headers. This decision is remembered for all Pi project settings and resources, not just MCP."))) {
        if (canConfirm) declinedCwd = ctx.cwd;
        warn(`skipping ${path}; use /trust to approve the project`);
        return;
      }
      try {
        pendingTrust.set(ctx.cwd, true);
      } catch (error) {
        warn(`cannot save project trust: ${String(error)}`);
        return;
      }
    }

    for (const [name, entry] of servers) {
      try {
        pi.registerMcpServer(name, convertServer(entry, (message) => warn(`${path} (${name}): ${message}`)));
        registered.add(name);
      } catch (error) {
        warn(`${path} (${name}): ${String(error)}`);
      }
    }
  });
}
