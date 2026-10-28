#!/usr/bin/env bun
import { $ } from "bun";
import { resolve } from "node:path";
import { parseArgs } from "node:util";
import { deployHost, exportProfile, remoteEnvironment, resolveHost } from "./deploy-pi-profile";

const root = resolve(import.meta.dir, "..");
const paseoFiles = [
  "scripts/work/setup-paseo-arch.ts",
  "modules/paseo/config.mjs",
  "home/config/paseo/config.json",
  "modules/paseo/arch/config.json",
  "modules/paseo/arch/pi-direnv",
  "modules/paseo/arch/paseo",
  "modules/paseo/arch/paseo-node.service",
  "modules/paseo/plugins/worktree-direnv/paseo-plugin.json",
  "modules/paseo/plugins/worktree-direnv/index.server.ts",
  "modules/paseo/plugins/worktree-direnv/server/direnv.ts",
  "modules/paseo/plugins/worktree-direnv/OVERVIEW.md",
  "modules/paseo/plugins/pi-fast/paseo-plugin.json",
  "modules/paseo/plugins/pi-fast/index.client.ts",
  "modules/paseo/plugins/pi-fast/OVERVIEW.md",
];

export async function exportPaseo(directory = root) {
  return (await $`tar -C ${directory} -cf - ${paseoFiles}`
    .env({ ...process.env, COPYFILE_DISABLE: "1" }).quiet()).stdout;
}

async function requireArchHost(target: string) {
  const command = remoteEnvironment
    + 'test -f /etc/arch-release || { echo "deploy-work requires an Arch host; use Nix to configure NixOS hosts." >&2; exit 1; }; '
    + 'command -v bun >/dev/null && command -v pi >/dev/null && command -v tar >/dev/null';
  await $`ssh -n ${target} ${command}`;
}

async function syncPaseo(target: string, archive: Buffer) {
  const command = remoteEnvironment
    + 'set -eu; stage=$(mktemp -d "${TMPDIR:-/tmp}/paseo-sync.XXXXXX"); '
    + 'trap \'rm -rf -- "$stage"\' EXIT; '
    + 'tar -xf - -C "$stage"; '
    + 'bun "$stage/scripts/work/setup-paseo-arch.ts" --config-only';
  await $`ssh ${target} ${command} < ${archive}`;
}

export async function deployWork(host: string, options: { "skip-packages"?: boolean } = {}) {
  const target = resolveHost(host);
  const archive = await exportPaseo();
  const profile = await exportProfile(undefined, root, "work");
  await requireArchHost(target);
  if (!await deployHost(target, profile, options, "work")) {
    throw new Error("Pi sync failed; Paseo configuration was not applied.");
  }
  await syncPaseo(target, archive);
  console.log(`${host}: sync complete`);
}

async function main() {
  const { values, positionals } = parseArgs({ allowPositionals: true, options: {
    "skip-packages": { type: "boolean" }, help: { type: "boolean" },
  } });
  if (values.help) {
    console.log("Usage: bun scripts/deploy-work.ts [--skip-packages] [SSH_HOST] (default: work)");
    console.log("Sync the local work Pi profile and Arch Paseo config without a remote checkout or service restart.");
    return;
  }
  if (positionals.length > 1) throw new Error("Expected one SSH host.");
  await deployWork(positionals[0] ?? "work", values);
}

if (import.meta.main) {
  try {
    await main();
  } catch (error) {
    console.error(error);
    process.exitCode = 1;
  }
}
