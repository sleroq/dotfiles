import * as fs from "node:fs/promises";
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

async function seedResource(home, relative, source, linked) {
  const target = path.join(home, relative);
  if (!(await needsSeed(target))) return;
  const backing = linked ? path.join(home, ".local/share/paseo/profile", relative) : target;
  await fs.mkdir(path.dirname(backing), { recursive: true, mode: 0o700 });
  if (linked) {
    if (!(await exists(backing))) await copyWritable(source, backing);
  }
  await fs.mkdir(path.dirname(target), { recursive: true, mode: 0o700 });
  if (await exists(target)) await fs.unlink(target);
  if (linked) await fs.symlink(backing, target);
  else await copyWritable(source, target);
}

export async function seedProfile(home, manifest) {
  for (const [relative, source] of Object.entries(manifest.links)) {
    await seedResource(home, relative, source, true);
  }
  for (const [relative, source] of Object.entries(manifest.files)) {
    await seedResource(home, relative, source, false);
  }
}

if (process.argv[1] && await fs.realpath(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [manifestPath, home] = process.argv.slice(2);
  await seedProfile(home, JSON.parse(await fs.readFile(manifestPath, "utf8")));
}
