import { readFile, writeFile, chmod, mkdir, rename } from "node:fs/promises";
import { join } from "node:path";

async function readState(path) {
  try {
    return JSON.parse(await readFile(path, "utf8"));
  } catch (error) {
    if (error.code === "ENOENT") return {};
    throw error;
  }
}

const hostLocal = new Set([
  "defaultThinkingLevel", "theme", "lastChangelogVersion", "deviceId",
]);

function packageIdentity(entry) {
  const source = typeof entry === "string" ? entry : entry.source;
  if (!source.startsWith("npm:")) return source;
  return source.replace(/(@[^/]*$)/, "");
}

function mergeSettings(defaults, current, managed) {
  const result = { ...current };
  for (const key of managed.settingsKeys ?? []) {
    if (!hostLocal.has(key)) delete result[key];
  }
  for (const [key, value] of Object.entries(defaults)) {
    if (!hostLocal.has(key) || !Object.hasOwn(current, key)) result[key] = value;
  }
  const shared = defaults.packages ?? [];
  const owned = new Set([...(managed.packages ?? []), ...shared.map(packageIdentity)]);
  result.packages = [...shared, ...(current.packages ?? []).filter(entry => !owned.has(packageIdentity(entry)))];
  return result;
}

function mergeMcp(defaults, current, managed) {
  const servers = { ...current.mcpServers };
  for (const name of managed.mcpServers ?? []) delete servers[name];
  for (const name of ["cloudflare", "cloudflare-docs"]) {
    if (!Object.hasOwn(defaults.mcpServers, name)) delete servers[name];
  }
  for (const [name, definition] of Object.entries(defaults.mcpServers)) {
    const existing = current.mcpServers?.[name] ?? {};
    servers[name] = { ...definition };
    for (const key of ["enabled", "exposure", "toolExposure", "auth", "headers", "oauth"]) {
      if (Object.hasOwn(existing, key)) servers[name][key] = existing[key];
    }
    if (existing.env) {
      servers[name].env = { ...existing.env, ...definition.env };
      if (Object.hasOwn(existing.env, "EXA_API_KEY") && existing.env.EXA_API_KEY !== "${EXA_API_KEY}") {
        servers[name].env.EXA_API_KEY = existing.env.EXA_API_KEY;
      }
    }
  }
  return { ...defaults, ...current, mcpServers: servers };
}

async function writeState(path, state) {
  const temporary = `${path}.profile-tmp`;
  await writeFile(temporary, `${JSON.stringify(state, null, 2)}\n`, { mode: 0o600 });
  await chmod(temporary, 0o600);
  await rename(temporary, path);
}

export async function syncProfile(settingsPath, mcpPath, directory, modelsPath) {
  const settingsDefaults = JSON.parse(await readFile(settingsPath, "utf8"));
  const mcpDefaults = JSON.parse(await readFile(mcpPath, "utf8"));
  await mkdir(directory, { recursive: true, mode: 0o700 });
  const settingsTarget = join(directory, "settings.json");
  const mcpTarget = join(directory, "mcp.json");
  const managedPath = join(directory, ".profile-managed.json");
  const managed = await readState(managedPath);
  await writeState(settingsTarget, mergeSettings(settingsDefaults, await readState(settingsTarget), managed));
  await writeState(mcpTarget, mergeMcp(mcpDefaults, await readState(mcpTarget), managed));
  if (modelsPath) {
    const defaults = JSON.parse(await readFile(modelsPath, "utf8"));
    const target = join(directory, "models.json");
    const current = await readState(target);
    const providers = { ...current.providers };
    for (const name of managed.providers ?? []) delete providers[name];
    for (const [name, definition] of Object.entries(defaults.providers ?? {})) {
      providers[name] = { ...definition };
      if (Object.hasOwn(current.providers?.[name] ?? {}, "apiKey")) {
        providers[name].apiKey = current.providers[name].apiKey;
      }
    }
    await writeState(target, { ...defaults, ...current, providers });
    managed.providers = Object.keys(defaults.providers ?? {});
  }
  await writeState(managedPath, {
    ...(managed.providers ? { providers: managed.providers } : {}),
    settingsKeys: Object.keys(settingsDefaults),
    packages: (settingsDefaults.packages ?? []).map(packageIdentity),
    mcpServers: Object.keys(mcpDefaults.mcpServers),
  });
}

if (import.meta.main) {
  await syncProfile(...process.argv.slice(2));
}
