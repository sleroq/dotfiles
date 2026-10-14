import { readFile, writeFile, chmod, mkdir, rename } from "node:fs/promises";
import { dirname } from "node:path";

const isObject = value => value !== null && typeof value === "object" && !Array.isArray(value);

export function mergeConfig(current, desired) {
  const result = isObject(current) ? { ...current } : {};
  for (const [key, value] of Object.entries(desired)) {
    result[key] = isObject(value) ? mergeConfig(result[key], value) : value;
  }
  return result;
}

export async function syncConfig(sourcePath, targetPath) {
  const desired = JSON.parse(await readFile(sourcePath, "utf8"));
  return writeConfig(desired, targetPath);
}

export async function writeConfig(desired, targetPath) {
  let current = {};
  try {
    current = JSON.parse(await readFile(targetPath, "utf8"));
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
  }
  await mkdir(dirname(targetPath), { recursive: true, mode: 0o700 });
  const temporary = `${targetPath}.config-tmp`;
  await writeFile(temporary, `${JSON.stringify(mergeConfig(current, desired), null, 2)}\n`, { mode: 0o600 });
  await chmod(temporary, 0o600);
  await rename(temporary, targetPath);
}

if (import.meta.main) {
  await syncConfig(process.argv[2], process.argv[3]);
}
