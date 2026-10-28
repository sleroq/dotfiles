import { afterEach, expect, test } from "bun:test";
import { chmod, lstat, mkdir, mkdtemp, readFile, readdir, readlink, rm, stat, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { seedProfile } from "./seed-profile.mjs";

const directories: string[] = [];

afterEach(async () => {
  for (const directory of directories.splice(0)) await rm(directory, { recursive: true, force: true });
});

async function fixture() {
  const directory = await mkdtemp(join(tmpdir(), "paseo-profile-"));
  directories.push(directory);
  const home = join(directory, "home");
  await mkdir(join(home, ".pi/agent"), { recursive: true });
  const first = join(directory, "generation-one");
  const second = join(directory, "generation-two");
  for (const source of [first, second]) {
    await mkdir(join(source, "extensions"), { recursive: true });
    await writeFile(join(source, "extensions/existing.ts"), source);
    await writeFile(join(source, "AGENTS.md"), source);
    await writeFile(join(source, "settings.json"), JSON.stringify({ source }));
  }
  await mkdir(join(second, "extensions/cumserver"));
  await writeFile(join(second, "extensions/cumserver/index.ts"), "new provider");
  function manifest(source: string) {
    return {
      links: {
        ".pi/agent/extensions": join(source, "extensions"),
        ".pi/agent/AGENTS.md": join(source, "AGENTS.md"),
      },
      files: { ".pi/agent/settings.json": join(source, "settings.json") },
    };
  }
  return { home, first, second, manifest, extensions: join(home, ".pi/agent/extensions") };
}

test("activation replaces a legacy writable release link and leaves that release untouched", async () => {
  const { home, first, second, manifest, extensions } = await fixture();
  await symlink(join(first, "extensions"), extensions);

  await seedProfile(home, manifest(second));

  expect(await readlink(extensions)).not.toBe(join(first, "extensions"));
  expect(await readFile(join(extensions, "cumserver/index.ts"), "utf8")).toBe("new provider");
  expect(await readdir(join(first, "extensions"))).toEqual(["existing.ts"]);
  expect(await readFile(join(home, ".pi/agent/AGENTS.md"), "utf8")).toBe(second);
});

test("new generations switch resources, remove obsolete entries, and support rollback", async () => {
  const { home, first, second, manifest, extensions } = await fixture();
  await writeFile(join(first, "extensions/obsolete.ts"), "old extension");
  await seedProfile(home, manifest(first));
  const oldRelease = await readlink(extensions);

  await seedProfile(home, manifest(second));
  expect(await readlink(extensions)).not.toBe(oldRelease);
  expect((await readdir(extensions)).sort()).toEqual(["cumserver", "existing.ts"]);
  expect(await readFile(join(extensions, "existing.ts"), "utf8")).toBe(second);

  await seedProfile(home, manifest(first));
  expect(await readlink(extensions)).toBe(oldRelease);
  expect((await readdir(extensions)).sort()).toEqual(["existing.ts", "obsolete.ts"]);
});

test("repeated activation reuses writable dependencies and preserves mutable state", async () => {
  const { home, first, second, manifest, extensions } = await fixture();
  const auth = join(home, ".pi/agent/auth.json");
  const settings = join(home, ".pi/agent/settings.json");
  await writeFile(auth, "private credentials", { mode: 0o600 });
  await seedProfile(home, manifest(first));
  const release = await readlink(extensions);
  await mkdir(join(extensions, "node_modules"));
  await writeFile(join(extensions, "node_modules/dependency.js"), "installed dependency");
  await writeFile(settings, "host-local settings");

  await seedProfile(home, manifest(first));
  expect(await readlink(extensions)).toBe(release);
  expect(await readFile(join(extensions, "node_modules/dependency.js"), "utf8")).toBe("installed dependency");
  expect((await stat(join(extensions, "existing.ts"))).mode & 0o777).toBe(0o600);

  await seedProfile(home, manifest(second));
  expect(await readFile(auth, "utf8")).toBe("private credentials");
  expect((await stat(auth)).mode & 0o777).toBe(0o600);
  expect(await readFile(settings, "utf8")).toBe("host-local settings");
  expect((await lstat(settings)).isSymbolicLink()).toBe(false);
});

test("existing real resource directories are backed up before switching", async () => {
  const { home, second, manifest, extensions } = await fixture();
  await mkdir(extensions);
  await writeFile(join(extensions, "local.ts"), "local extension");
  await seedProfile(home, manifest(second));

  expect((await lstat(extensions)).isSymbolicLink()).toBe(true);
  const backups = join(home, ".local/share/paseo/profile/backups");
  const entries = await readdir(backups);
  expect(entries).toHaveLength(1);
  for (const backup of entries) {
    expect(await readFile(join(backups, backup, "extensions/local.ts"), "utf8")).toBe("local extension");
  }
});

test("failed preparation leaves active links unchanged and does not reuse a partial release", async () => {
  const { home, first, second, manifest, extensions } = await fixture();
  await seedProfile(home, manifest(first));
  const active = await readlink(extensions);
  const next = manifest(second);
  await rm(join(second, "AGENTS.md"));

  await expect(seedProfile(home, next)).rejects.toThrow();
  expect(await readlink(extensions)).toBe(active);

  await writeFile(join(second, "AGENTS.md"), "restored");
  await chmod(join(second, "extensions/existing.ts"), 0o755);
  await seedProfile(home, next);
  expect(await readFile(join(extensions, "cumserver/index.ts"), "utf8")).toBe("new provider");
  expect((await stat(join(extensions, "existing.ts"))).mode & 0o777).toBe(0o700);
});
