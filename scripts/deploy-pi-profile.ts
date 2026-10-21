#!/usr/bin/env bun
import { $ } from "bun";
import { createHash } from "node:crypto";
import { lstatSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { dirname, join, relative, resolve } from "node:path";
import { parseArgs } from "node:util";
import type { ProfileMetadata } from "../modules/paseo/install-profile.ts";

const root = resolve(import.meta.dir, "..");
const aliases = new Map([["work", "work"], ["cumserver", "paseo@cumserver"], ["desktop", "paseo@desktop"]]);
const installerFiles = ["modules/paseo/pi-profile.mjs", "modules/paseo/install-profile.ts", "modules/paseo/ast-grep.ts"];

interface ProfileBundle {
  metadata: ProfileMetadata;
  archive: Buffer;
}

interface ArchiveEntry {
  data: Buffer;
  mode: number;
}

interface DeploymentOptions {
  check?: boolean;
  "skip-packages"?: boolean;
}

async function git(directory: string, ...args: string[]) {
  return (await $`git -C ${directory} ${args}`.quiet()).stdout;
}

function resourceName(path: string) {
  if (path === "home/config/agents/AGENTS.md") return "pi/AGENTS.md";
  if (path.split("/").some(part => ["auth.json", "mcp-auth.json", "sessions", "provider-keys"].includes(part))) return;
  const prefix = "home/config/pi/agent/";
  if (path.startsWith(prefix)) {
    const name = path.slice(prefix.length);
    if (["AGENTS.md", "models.json", "settings.json", "mcp.json"].includes(name)
      || ["agents", "extensions", "prompts", "sounds"].includes(name.split("/")[0] ?? "")) return `pi/${name}`;
  }
  for (const [prefix, target] of [["home/config/agents/skills/", "skills/"], ["home/config/ast-grep/", "ast-grep/"]]) {
    if (prefix && path.startsWith(prefix)) return target + path.slice(prefix.length);
  }
  if (installerFiles.includes(path)) {
    return path;
  }
}

export async function exportProfile(ref?: string, directory = root, host?: string): Promise<ProfileBundle> {
  directory = realpathSync(directory);
  const commit = (await git(directory, "rev-parse", "--verify", `${ref ?? "HEAD"}^{commit}`)).toString().trim();
  const paths = (ref
    ? await git(directory, "ls-tree", "-r", "--name-only", "-z", commit)
    : await git(directory, "ls-files", "-z")).toString().split("\0");
  if (!ref) {
    paths.push(...installerFiles, "home/config/agents/AGENTS.md", "home/config/ast-grep/svelte-parser.json");
  }
  const files = new Map<string, ArchiveEntry>();
  for (const path of new Set(paths)) {
    const name = resourceName(path);
    if (!name) continue;
    let data: Buffer;
    let executable: boolean;
    if (ref) {
      const mode = (await git(directory, "ls-tree", commit, "--", path)).toString().split(/\s/)[0];
      if (mode === "120000") throw new Error(`Ref resource is a symlink: ${path}`);
      data = await git(directory, "cat-file", "--filters", `${commit}:${path}`);
      executable = mode === "100755";
    } else {
      const source = join(directory, path);
      const stat = lstatSync(source, { throwIfNoEntry: false });
      if (!stat) continue;
      if (stat.isSymbolicLink() || relative(directory, realpathSync(source)).startsWith("../")) {
        throw new Error(`Resource escapes repository: ${path}`);
      }
      data = readFileSync(source);
      executable = Boolean(stat.mode & 0o111);
    }
    if (name === "ast-grep/sgconfig.yml" && host === "work") {
      data = Buffer.from(data.toString().replace("  - rules/common", "  - rules"));
    }
    if (name === "pi/settings.json" && host === "work") {
      const settings = JSON.parse(data.toString());
      settings.httpProxy = "http://127.0.0.1:2080";
      data = Buffer.from(`${JSON.stringify(settings, null, 2)}\n`);
    }
    if (name === "pi/mcp.json") {
      const mcp = JSON.parse(data.toString());
      for (const server of ["cloudflare", "cloudflare-docs"]) delete mcp.mcpServers[server];
      if (host === "work") {
        mcp.mcpServers.exa.env = {
          ...mcp.mcpServers.exa.env,
          EXA_API_KEY: '!. "$HOME/.config/pi/exa.env" && printf %s "$EXA_API_KEY"',
          HTTP_PROXY: "http://127.0.0.1:2080",
          HTTPS_PROXY: "http://127.0.0.1:2080",
          NO_PROXY: "",
          NODE_USE_ENV_PROXY: "1",
        };
      }
      data = Buffer.from(`${JSON.stringify(mcp, null, 2)}\n`);
    }
    files.set(name, { data, mode: executable ? 0o700 : 0o600 });
  }

  const required = ["pi/AGENTS.md", "pi/settings.json", "pi/mcp.json", "pi/models.json", "modules/paseo/pi-profile.mjs", "modules/paseo/install-profile.ts"];
  const missing = required.filter(name => !files.has(name));
  if (missing.length) throw new Error(`Profile source lacks required files: ${missing.join(", ")}`);
  const digest = createHash("sha256");
  for (const [name, { data }] of [...files].sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0)) {
    digest.update(`${name}\0${data.length}\0`);
    digest.update(data);
  }
  const metadata = {
    sourceCommit: commit, contentDigest: digest.digest("hex"),
    dirty: !ref && Boolean((await git(directory, "status", "--porcelain", "--untracked-files=no")).length),
  };
  files.set("manifest.json", { data: Buffer.from(`${JSON.stringify(metadata, null, 2)}\n`), mode: 0o600 });
  return { metadata, archive: await archiveFiles(files) };
}

async function archiveFiles(files: Map<string, ArchiveEntry>) {
  const staging = mkdtempSync(join(tmpdir(), "pi-profile-"));
  try {
    for (const [name, { data, mode }] of files) {
      const target = join(staging, name);
      mkdirSync(dirname(target), { recursive: true, mode: 0o700 });
      writeFileSync(target, data, { mode });
    }
    return (await $`tar -C ${staging} -cf - .`.quiet()).stdout;
  } finally {
    rmSync(staging, { recursive: true, force: true });
  }
}

function quote(value: string) {
  return `'${value.replaceAll("'", "'\\''")}'`;
}

async function syncExaEnv(target: string, check: boolean) {
  const identity = join(homedir(), ".ssh/id_ed25519");
  const source = join(root, "shared/secrets/exa-env");
  const secret = (await $`age --decrypt -i ${identity} ${source}`.quiet()).stdout;
  const digest = createHash("sha256").update(secret).digest("hex");
  const remote = check
    ? 'test "$(sha256sum "$HOME/.config/pi/exa.env" | cut -d " " -f 1)" = ' + quote(digest)
      + ' && test "$(stat -c %a "$HOME/.config/pi/exa.env")" = 600'
    : 'umask 077; install -d -m 700 "$HOME/.config/pi" && install -m 600 /dev/stdin "$HOME/.config/pi/exa.env"';
  const result = check
    ? await $`ssh -n ${target} ${remote}`.quiet().nothrow()
    : await $`ssh ${target} ${remote} < ${secret}`.quiet();
  return result.exitCode === 0;
}

export function resolveHost(host: string) {
  const target = aliases.get(host) ?? host;
  if (target.startsWith("-")) throw new Error("SSH target cannot start with '-'");
  return target;
}

export const remoteEnvironment = 'export PATH="$HOME/.local/bin:$HOME/.bun/bin:$HOME/.npm/bin:$HOME/.nix-profile/bin:/run/current-system/sw/bin:/etc/profiles/per-user/$(id -un)/bin:$PATH"; ';

export async function deployHost(host: string, bundle: ProfileBundle, options: DeploymentOptions, profile = host) {
  const target = resolveHost(host);
  const secretsCurrent = profile !== "work" || await syncExaEnv(target, options.check ?? false);
  const args = [JSON.stringify(bundle.metadata), options.check ? "check" : "apply", String(options["skip-packages"] ?? false)];
  const release = 'release="$HOME/.local/share/pi-profile/releases/"' + quote(bundle.metadata.contentDigest) + '; ';
  const prepare = options.check ? '[ -f "$release/modules/paseo/install-profile.ts" ] || exit 1; '
    : 'umask 077; mkdir -p "$release" || exit; tar -xmf - -C "$release" || exit; ';
  const workRuntime = profile !== "work" ? "" : options.check
    ? `zsh -lic 'test "$(readlink -f "$(command -v pi)")" = "$(readlink -f /usr/bin/pi)"' || exit 1; `
    : 'mkdir -p "$HOME/.local/bin" || exit; ln -sfn /usr/bin/pi "$HOME/.local/bin/pi" || exit; ';
  const remote = remoteEnvironment + release + prepare + workRuntime + 'exec bun "$release/modules/paseo/install-profile.ts" ' + args.map(quote).join(" ");
  const result = options.check
    ? await $`ssh -n ${target} ${remote}`.nothrow()
    : await $`ssh ${target} ${remote} < ${bundle.archive}`.nothrow();
  const success = result.exitCode === 0 && secretsCurrent;
  const state = success ? (options.check ? "current" : "applied") : (options.check ? "outdated/unreachable" : "FAILED");
  const { sourceCommit, contentDigest, dirty } = bundle.metadata;
  console.log(`${host}: ${state} commit=${sourceCommit} digest=${contentDigest} dirty=${dirty}`);
  return success;
}

async function main() {
  const { values, positionals } = parseArgs({ allowPositionals: true, options: {
    check: { type: "boolean" }, ref: { type: "string" }, "skip-packages": { type: "boolean" }, help: { type: "boolean" },
  } });
  if (values.help) {
    console.log("Usage: bun scripts/deploy-pi-profile.ts [--check] [--ref REV] [--skip-packages] [HOST ...] (default: work)");
    return;
  }
  let success = true;
  for (const host of positionals.length ? positionals : ["work"]) {
    try {
      const bundle = await exportProfile(values.ref, root, host);
      success = await deployHost(host, bundle, values) && success;
    } catch (error) {
      console.error(`${host}: FAILED:`, error);
      success = false;
    }
  }
  process.exitCode = success ? 0 : 1;
}

if (import.meta.main) await main();
