import * as fs from "node:fs/promises";
import { createHash } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";

async function exists(target) {
  try {
    return await fs.lstat(target);
  } catch (error) {
    if (error.code === "ENOENT") return null;
    throw error;
  }
}

async function needsSeed(target) {
  const stat = await exists(target);
  if (!stat) return true;
  if (!stat.isSymbolicLink()) return false;
  const destination = path.resolve(path.dirname(target), await fs.readlink(target));
  if (destination.startsWith("/nix/store/")) return true;
  try {
    return (await fs.realpath(target)).startsWith("/nix/store/");
  } catch (error) {
    if (error.code === "ENOENT") return false;
    throw error;
  }
}

async function copyWritable(source, target) {
  const stat = await fs.stat(source);
  if (stat.isDirectory()) {
    await fs.mkdir(target, { recursive: true, mode: 0o700 });
    await fs.chmod(target, 0o700);
    for (const name of await fs.readdir(source)) {
      await copyWritable(path.join(source, name), path.join(target, name));
    }
  } else {
    await fs.copyFile(source, target);
    await fs.chmod(target, stat.mode & 0o111 ? 0o700 : 0o600);
  }
}

async function prepareRelease(home, links) {
  // Nix source paths identify their contents; a changed source selects a new release.
  const sources = Object.entries(links).sort(([a], [b]) => a.localeCompare(b));
  const generation = createHash("sha256").update(JSON.stringify(sources)).digest("hex");
  const releases = path.join(home, ".local/share/paseo/profile/releases");
  const release = path.join(releases, generation);
  if (await exists(release)) return release;

  await fs.mkdir(releases, { recursive: true, mode: 0o700 });
  const staging = await fs.mkdtemp(path.join(releases, ".staging-"));
  try {
    for (const [relative, source] of sources) {
      const target = path.join(staging, relative);
      await fs.mkdir(path.dirname(target), { recursive: true, mode: 0o700 });
      await copyWritable(source, target);
    }
    await fs.rename(staging, release);
  } finally {
    await fs.rm(staging, { recursive: true, force: true });
  }
  return release;
}

async function linkResource(home, relative, source) {
  const target = path.join(home, relative);
  const stat = await exists(target);
  if (stat?.isSymbolicLink() && await fs.readlink(target) === source) return;
  await fs.mkdir(path.dirname(target), { recursive: true, mode: 0o700 });
  if (stat && !stat.isSymbolicLink()) {
    const backups = path.join(home, ".local/share/paseo/profile/backups");
    await fs.mkdir(backups, { recursive: true, mode: 0o700 });
    const backup = await fs.mkdtemp(path.join(backups, "resource-"));
    await fs.rename(target, path.join(backup, path.basename(target)));
  }
  const temporary = `${target}.profile-tmp`;
  await fs.symlink(source, temporary);
  await fs.rename(temporary, target);
}

async function seedFile(home, relative, source) {
  const target = path.join(home, relative);
  if (!(await needsSeed(target))) return;
  await fs.mkdir(path.dirname(target), { recursive: true, mode: 0o700 });
  if (await exists(target)) await fs.unlink(target);
  await copyWritable(source, target);
}

export async function seedProfile(home, manifest) {
  const release = await prepareRelease(home, manifest.links);
  for (const relative of Object.keys(manifest.links)) {
    await linkResource(home, relative, path.join(release, relative));
  }
  for (const [relative, source] of Object.entries(manifest.files)) {
    await seedFile(home, relative, source);
  }
}

if (process.argv[1] && await fs.realpath(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [manifestPath, home] = process.argv.slice(2);
  await seedProfile(home, JSON.parse(await fs.readFile(manifestPath, "utf8")));
}
