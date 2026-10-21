import { execFile } from "node:child_process";
import { lstatSync, statSync } from "node:fs";
import { writeFile } from "node:fs/promises";
import { join } from "node:path";
import { promisify } from "node:util";
import type { PaseoWorkspace } from "@getpaseo/client";

const execFileAsync = promisify(execFile);

type DirenvWorkspace = Pick<PaseoWorkspace,
  "workspaceKind" | "worktreeSlug" | "workspaceDirectory" | "projectRootPath">;

async function gitMatches(cwd: string, args: string[]) {
  try {
    await execFileAsync("git", ["-C", cwd, ...args]);
    return true;
  } catch (error) {
    if (error instanceof Error && "code" in error && error.code === 1) return false;
    throw error;
  }
}

export async function ensureDirenv(workspace: DirenvWorkspace) {
  if (workspace.workspaceKind !== "worktree" || !workspace.worktreeSlug) return;

  const target = join(workspace.workspaceDirectory, ".envrc");
  if (lstatSync(target, { throwIfNoEntry: false })) return;

  const source = join(workspace.projectRootPath, ".envrc");
  if (!statSync(source, { throwIfNoEntry: false })?.isFile()) return;
  if (!await gitMatches(workspace.projectRootPath, ["check-ignore", "--quiet", "--", ".envrc"])) return;
  if (await gitMatches(workspace.workspaceDirectory, ["ls-files", "--error-unmatch", "--", ".envrc"])) return;

  const quotedSource = "'" + source.replaceAll("'", "'\\''") + "'";
  try {
    await writeFile(target, `# Paseo worktree-direnv: review this file, then run direnv allow.\nsource_env ${quotedSource}\n`, {
      flag: "wx",
      mode: 0o600,
    });
  } catch (error) {
    // Workspace creation and session opening can invoke the plugin concurrently.
    if (error instanceof Error && "code" in error && error.code === "EEXIST") return;
    throw error;
  }
}
