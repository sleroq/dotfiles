import { execFile } from "node:child_process";
import { constants, lstatSync } from "node:fs";
import { cp, mkdir } from "node:fs/promises";
import { dirname, join } from "node:path";
import { promisify } from "node:util";

import defaultPolicy from "./copy-policy.json" with { type: "json" };

const execFileAsync = promisify(execFile);

type CopyPolicy = { include: readonly string[]; exclude: readonly string[] };

export async function copyIgnoredFiles(source: string, target: string, policy: CopyPolicy = defaultPolicy) {
  if (policy.include.length === 0) return;
  const { stdout } = await execFileAsync("git", [
    "-C", source, "ls-files", "--others", "--ignored", "--exclude-standard", "-z", "--",
    ...policy.include.map(pattern => `:(glob)${pattern}`),
    ...policy.exclude.map(pattern => `:(glob,exclude)${pattern}`),
  ], { maxBuffer: 64 * 1024 * 1024 });

  for (const file of stdout.split("\0").filter(Boolean)) {
    const destination = join(target, file);
    if (lstatSync(destination, { throwIfNoEntry: false })) continue;

    // A different branch may track a symlink where the source has a directory.
    for (let parent = dirname(destination); parent !== target; parent = dirname(parent)) {
      const entry = lstatSync(parent, { throwIfNoEntry: false });
      if (entry && !entry.isDirectory()) {
        throw new Error(`Cannot copy ignored file through a non-directory: ${parent}`);
      }
    }

    await mkdir(dirname(destination), { recursive: true });
    await cp(join(source, file), destination, {
      force: false,
      verbatimSymlinks: true,
      mode: constants.COPYFILE_FICLONE,
    });
  }
}
