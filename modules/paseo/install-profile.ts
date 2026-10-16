import { $ } from "bun";
import { chmodSync, copyFileSync, existsSync, lstatSync, mkdirSync, readFileSync, readlinkSync, renameSync, symlinkSync, unlinkSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { basename, dirname, join, relative, resolve } from "node:path";
import { installAstGrep } from "./ast-grep";

export interface ProfileMetadata {
  sourceCommit: string;
  contentDigest: string;
  dirty: boolean;
}

interface DeploymentRecord extends ProfileMetadata {
  packagesReconciled: boolean;
}

interface PackageDeclaration {
  source: string;
}

interface SharedSettings {
  packages?: (string | PackageDeclaration)[];
}

interface SharedMcp {
  mcpServers: Record<string, { enabled?: boolean }>;
}

export function profileIsCurrent(metadata: ProfileMetadata, skipPackages: boolean, home = homedir()) {
  const record = join(home, ".pi/agent/.profile-deployment.json");
  if (!existsSync(record)) return false;
  const actual: DeploymentRecord = JSON.parse(readFileSync(record, "utf8"));
  return actual.contentDigest === metadata.contentDigest && (skipPackages || actual.packagesReconciled === true);
}

function linkResource(target: string, source: string, home: string, backup: string) {
  const stat = lstatSync(target, { throwIfNoEntry: false });
  if (stat?.isSymbolicLink() && resolve(dirname(target), readlinkSync(target)) === source) return;
  if (stat) {
    const destination = join(backup, relative(home, target));
    mkdirSync(dirname(destination), { recursive: true });
    renameSync(target, destination);
  }
  mkdirSync(dirname(target), { recursive: true });
  symlinkSync(source, target);
}

function backUpMutableProfile(agent: string, backup: string) {
  for (const name of ["models.json", "settings.json", "mcp.json"]) {
    const source = join(agent, name);
    if (!existsSync(source)) continue;
    const destination = join(backup, ".pi/agent", name);
    mkdirSync(dirname(destination), { recursive: true });
    copyFileSync(source, destination);
    chmodSync(destination, 0o600);
  }
}

function linkProfileResources(release: string, agent: string, home: string, backup: string) {
  for (const name of ["AGENTS.md", "agents", "extensions", "prompts", "sounds"]) {
    const source = join(release, "pi", name);
    if (name !== "AGENTS.md") mkdirSync(source, { recursive: true });
    linkResource(join(agent, name), source, home, backup);
  }
  mkdirSync(join(release, "skills"), { recursive: true });
  linkResource(join(home, ".agents/skills"), join(release, "skills"), home, backup);
  linkResource(join(home, ".config/ast-grep"), join(release, "ast-grep"), home, backup);
  linkResource(join(home, "sgconfig.yml"), join(release, "sgconfig.yml"), home, backup);
  linkResource(join(home, "develop/frg/sgconfig.yml"), join(release, "sgconfig-frg.yml"), home, backup);
}

function prepareRemoteMcp(release: string) {
  const mcp: SharedMcp = JSON.parse(readFileSync(join(release, "pi/mcp.json"), "utf8"));
  for (const name of ["cloudflare", "cloudflare-docs"]) delete mcp.mcpServers[name];
  (mcp.mcpServers["chrome-android"] ??= {}).enabled = false;
  writeFileSync(join(release, "remote-mcp.json"), JSON.stringify(mcp));
}

function sharedPackageSources(release: string) {
  const settings: SharedSettings = JSON.parse(readFileSync(join(release, "pi/settings.json"), "utf8"));
  return (settings.packages ?? []).map(entry => typeof entry === "string" ? entry : entry.source);
}

async function syncProfile(release: string, agent: string, home: string, env: NodeJS.ProcessEnv) {
  const args = [join(release, "modules/paseo/pi-profile.mjs"), join(release, "pi/settings.json"), join(release, "remote-mcp.json"), agent, join(release, "pi/models.json")];
  await $`${process.execPath} ${args}`.env(env).cwd(home);
}

export async function installProfile(metadata: ProfileMetadata, skipPackages: boolean, release: string, home = homedir()) {
  process.umask(0o077);
  const agent = join(home, ".pi/agent");
  const record = join(agent, ".profile-deployment.json");
  const backup = join(home, ".local/share/pi-profile/backups", `${new Date().toISOString().replace(/[:.]/g, "-")}-${process.pid}`);
  mkdirSync(agent, { recursive: true });
  if (!existsSync(record)) backUpMutableProfile(agent, backup);
  if (existsSync(record)) unlinkSync(record);
  const env: NodeJS.ProcessEnv = { ...process.env, NPM_CONFIG_REGISTRY: "https://registry.npmjs.org" };
  env.PATH = [".local/bin", ".bun/bin", ".npm/bin", ".nix-profile/bin"].map(p => join(home, p))
    .concat(["/run/current-system/sw/bin", `/etc/profiles/per-user/${basename(home)}/bin`, env.PATH ?? ""]).join(":");
  await installAstGrep(release, env);
  linkProfileResources(release, agent, home, backup);
  prepareRemoteMcp(release);
  await syncProfile(release, agent, home, env);
  if (!skipPackages) {
    const pi = Bun.which("pi", { PATH: env.PATH });
    if (!pi) throw new Error("Required command not found: pi");
    for (const source of sharedPackageSources(release)) {
      await $`${pi} install ${source} --no-approve`.env(env).cwd(home);
    }
    await syncProfile(release, agent, home, env);
  }

  const deployment: DeploymentRecord = { ...metadata, packagesReconciled: !skipPackages };
  writeFileSync(record, `${JSON.stringify(deployment, null, 2)}\n`, { mode: 0o600 });
  chmodSync(record, 0o600);
}

if (import.meta.main) {
  const [encoded, operation, skip] = process.argv.slice(2);
  if (!encoded) throw new Error("Expected deployment metadata");
  const metadata: ProfileMetadata = JSON.parse(encoded);
  if (operation === "check") process.exitCode = profileIsCurrent(metadata, skip === "true") ? 0 : 1;
  else await installProfile(metadata, skip === "true", resolve(import.meta.dir, "../.."));
}
