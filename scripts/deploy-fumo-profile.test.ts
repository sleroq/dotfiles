import { afterEach, expect, test } from "bun:test";
import { $ } from "bun";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { exportProfile } from "./deploy-pi-profile";

const directories: string[] = [];
const packageSource = "npm:@fumo-gateway/pi@1.0.0";

afterEach(() => {
  for (const directory of directories.splice(0)) rmSync(directory, { recursive: true, force: true });
});

function write(directory: string, path: string, contents: string) {
  const target = join(directory, path);
  mkdirSync(dirname(target), { recursive: true });
  writeFileSync(target, contents);
}

async function commit(directory: string) {
  await $`git -C ${directory} add .`.quiet();
  await $`git -C ${directory} -c user.name=Fixture -c user.email=fixture@example.test -c commit.gpgsign=false commit -qm fixture`.quiet();
}

async function fixture() {
  const directory = mkdtempSync(join(tmpdir(), "fumo profile "));
  directories.push(directory);
  const repository = join(directory, "dotfiles");
  write(repository, "home/config/agents/AGENTS.md", "fixture instructions\n");
  write(repository, "home/config/pi/agent/settings.json", JSON.stringify({ packages: [packageSource] }));
  write(repository, "home/config/pi/agent/mcp.json", JSON.stringify({ mcpServers: { exa: { env: { EXA_API_KEY: "${EXA_API_KEY}" } } } }));
  write(repository, "home/config/pi/agent/models.json", "{}");
  write(repository, "home/config/pi/agent/auth.json", "fixture-private-credential");
  write(repository, "home/config/pi/agent/extensions/other.ts", "export default function () {}\n");
  for (const file of ["pi-profile.mjs", "install-profile.ts", "ast-grep.ts"]) {
    write(repository, `modules/paseo/${file}`, "export {};\n");
  }
  await $`git -C ${repository} init -q`.quiet();
  await commit(repository);
  return { directory, repository };
}

async function unpack(archive: Buffer, directory: string) {
  const release = join(directory, "release");
  mkdirSync(release);
  await $`tar -xf - -C ${release} < ${archive}`.quiet();
  const entries = (await $`tar -tf - < ${archive}`.quiet()).stdout.toString();
  return { release, entries };
}

test("exports the published Fumo package without a source checkout or duplicate extension", async () => {
  const { directory, repository } = await fixture();
  const bundle = await exportProfile(undefined, repository, "work");
  const { release, entries } = await unpack(bundle.archive, directory);
  const settings = JSON.parse(readFileSync(join(release, "pi/settings.json"), "utf8"));
  expect(settings.packages).toEqual([packageSource]);
  expect(settings.httpProxy).toBe("http://127.0.0.1:2080");
  expect(settings.extensions).toBeUndefined();
  expect(entries).toContain("./pi/extensions/other.ts");
  for (const excluded of ["pi/extensions/fumo/", "auth.json", "gateway.json", "node_modules"]) {
    expect(entries).not.toContain(excluded);
  }
});

test("published package version participates in the profile digest", async () => {
  const { repository } = await fixture();
  const first = await exportProfile(undefined, repository);
  write(repository, "home/config/pi/agent/settings.json", JSON.stringify({ packages: ["npm:@fumo-gateway/pi@1.0.1"] }));
  const second = await exportProfile(undefined, repository);
  expect(second.metadata.sourceCommit).toBe(first.metadata.sourceCommit);
  expect(second.metadata.contentDigest).not.toBe(first.metadata.contentDigest);
  expect(second.metadata.dirty).toBe(true);
});

test("historical refs keep their original Fumo implementation and settings", async () => {
  const { directory, repository } = await fixture();
  const old = "export default function historicalFumo() {}\n";
  write(repository, "home/config/pi/agent/settings.json", "{}");
  write(repository, "home/config/pi/agent/extensions/fumo/index.ts", old);
  await commit(repository);
  rmSync(join(repository, "home/config/pi/agent/extensions/fumo"), { recursive: true });
  write(repository, "home/config/pi/agent/settings.json", JSON.stringify({ packages: [packageSource] }));
  const bundle = await exportProfile("HEAD", repository);
  const { release, entries } = await unpack(bundle.archive, directory);
  expect(readFileSync(join(release, "pi/extensions/fumo/index.ts"), "utf8")).toBe(old);
  expect(JSON.parse(readFileSync(join(release, "pi/settings.json"), "utf8")).packages).toBeUndefined();
  expect(entries).not.toContain("provider.ts");
  expect(bundle.metadata.dirty).toBe(false);
});
