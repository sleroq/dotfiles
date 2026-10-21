import { expect, test } from "bun:test";
import { $ } from "bun";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, readlinkSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { exportPaseo } from "./deploy-work";

const root = resolve(import.meta.dir, "..");

interface Event {
  phase: string;
  args: string[];
  files?: string[];
  proxy?: string;
}

async function deployFixture(failPhase = "", extra: string[] = ["--skip-packages"]) {
  const directory = mkdtempSync(join(tmpdir(), "deploy-work-"));
  const bin = join(directory, "bin");
  const home = join(directory, "home");
  const log = join(directory, "events.jsonl");
  mkdirSync(bin);
  mkdirSync(home);

  writeFileSync(join(bin, "ssh"), `#!${process.execPath}
import {appendFileSync} from "node:fs";
const args=process.argv.slice(2);
const command=args.at(-1);
const phase=command.includes("/etc/arch-release")?"preflight":command.includes("install-profile.ts")?"pi":command.includes("setup-paseo-arch.ts")?"paseo":"secret";
const input=args.includes("-n")?Buffer.alloc(0):Buffer.from(await Bun.stdin.arrayBuffer());
const event={phase,args};
async function tar(...args) {
 const child=Bun.spawn(["tar",...args],{stdin:"pipe",stdout:"pipe",stderr:"pipe"});
 child.stdin.write(input);
 child.stdin.end();
 const text=await new Response(child.stdout).text();
 if(await child.exited) throw new Error(await new Response(child.stderr).text());
 return text;
}
if(phase==="pi"||phase==="paseo") event.files=(await tar("-tf","-")).trim().split("\\n");
if(phase==="pi") event.proxy=JSON.parse(await tar("-xOf","-","./pi/settings.json")).httpProxy;
appendFileSync(process.env.TEST_LOG,JSON.stringify(event)+"\\n");
if(phase===process.env.FAIL_PHASE) process.exit(23);
if(phase==="paseo") {
 const child=Bun.spawn(["sh","-c",command],{env:process.env,stdin:"pipe",stdout:"inherit",stderr:"inherit"});
 child.stdin.write(input);
 child.stdin.end();
 process.exit(await child.exited);
}
`, { mode: 0o700 });
  writeFileSync(join(bin, "age"), `#!${process.execPath}
import {appendFileSync} from "node:fs";
appendFileSync(process.env.TEST_LOG,JSON.stringify({phase:"age",args:process.argv.slice(2)})+"\\n");
process.stdout.write("EXA_API_KEY=test-only\\n");
`, { mode: 0o700 });
  for (const command of ["sudo", "systemctl", "paru"]) {
    writeFileSync(join(bin, command), `#!/bin/sh\nprintf 'Unexpected service/package operation: ${command}\\n' >&2\nexit 99\n`, { mode: 0o700 });
  }

  async function sync() {
    return await $`${process.execPath} ${join(root, "scripts/deploy-work.ts")} ${extra} oleg@arch-example`
      .env({ ...process.env, HOME: home, PATH: `${bin}:${process.env.PATH}`, TEST_LOG: log, FAIL_PHASE: failPhase })
      .quiet().nothrow();
  }
  const result = await sync();
  const events: Event[] = existsSync(log) ? readFileSync(log, "utf8").trim().split("\n").map(line => JSON.parse(line)) : [];
  return { directory, home, result, events, sync };
}

test("Paseo archive contains current runtime files without secrets, dependencies, or tests", async () => {
  const archive = await exportPaseo();
  const files = (await $`tar -tf - < ${archive}`.quiet()).stdout.toString().trim().split("\n");
  expect(files).toContain("scripts/work/setup-paseo-arch.ts");
  expect(files).toContain("modules/paseo/plugins/worktree-direnv/server/direnv.ts");
  expect(files.some(path => /secrets|node_modules|\.test\.|package-lock/.test(path))).toBe(false);
  expect((await $`tar -xOf - scripts/work/setup-paseo-arch.ts < ${archive}`.quiet()).stdout.toString())
    .toBe(readFileSync(join(root, "scripts/work/setup-paseo-arch.ts"), "utf8"));
});

test("syncs Pi and Paseo to an arbitrary SSH host without a checkout or service operations", async () => {
  const { directory, home, result, events } = await deployFixture();
  try {
    expect(result.exitCode, result.stderr.toString()).toBe(0);
    expect(events.map(event => event.phase)).toEqual(["preflight", "age", "secret", "pi", "paseo"]);
    for (const event of events.filter(event => event.phase !== "age")) {
      expect(event.args.at(-2)).toBe("oleg@arch-example");
    }
    const pi = events.find(event => event.phase === "pi")!;
    expect(pi.proxy).toBe("http://127.0.0.1:2080");
    expect(pi.args.at(-1)).toEndWith("'apply' 'true'");
    const config = JSON.parse(readFileSync(join(home, ".paseo/config.json"), "utf8"));
    expect(config.pluginsEnabled).toBe(true);
    expect(config.plugins["worktree-direnv"].path).toBe(join(home, ".config/paseo/plugins/worktree-direnv"));
    expect(readlinkSync(join(home, ".local/bin/pi"))).toBe("/usr/bin/pi");
    expect(readdirSync(join(home, ".config/paseo/plugins/worktree-direnv/server"))).toEqual(["direnv.ts"]);
    expect(result.stdout.toString()).toContain("Paseo: updated");
    expect(result.stdout.toString()).toContain("oleg@arch-example: sync complete");
    expect(result.stdout.toString()).not.toContain("systemctl");
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test("repeated sync reports Paseo unchanged without a restart notice or redundant backup", async () => {
  const { directory, home, result, sync } = await deployFixture();
  try {
    expect(result.exitCode, result.stderr.toString()).toBe(0);
    const configBefore = readFileSync(join(home, ".paseo/config.json"), "utf8");
    const repeat = await sync();
    expect(repeat.exitCode, repeat.stderr.toString()).toBe(0);
    expect(repeat.stdout.toString()).toContain("Paseo: unchanged");
    expect(repeat.stdout.toString()).not.toContain("Paseo: updated");
    expect(repeat.stdout.toString()).not.toContain("restart");
    expect(readFileSync(join(home, ".paseo/config.json"), "utf8")).toBe(configBefore);
    expect(existsSync(join(home, ".paseo/backups"))).toBe(false);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test.each([
  ["preflight", ["preflight"]],
  ["secret", ["preflight", "age", "secret"]],
  ["pi", ["preflight", "age", "secret", "pi"]],
  ["paseo", ["preflight", "age", "secret", "pi", "paseo"]],
])("stops after %s fails and returns a failure exit code", async (phase, expected) => {
  const { directory, home, result, events } = await deployFixture(phase);
  try {
    expect(result.exitCode).not.toBe(0);
    expect(events.map(event => event.phase)).toEqual(expected);
    expect(existsSync(join(home, ".paseo/config.json"))).toBe(false);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test("syncs Pi packages by default without installing system packages", async () => {
  const { directory, result, events } = await deployFixture("", []);
  try {
    expect(result.exitCode, result.stderr.toString()).toBe(0);
    expect(events.find(event => event.phase === "pi")!.args.at(-1)).toEndWith("'apply' 'false'");
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});
