import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { existsSync, lstatSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, statSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import type { TestContext } from "node:test";
import { ensureDirenv } from "./direnv.ts";

function fixture(t: TestContext) {
  const root = realpathSync(mkdtempSync(join(tmpdir(), "paseo-worktree-direnv-")));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const source = join(root, "repo with ' quotes $HOME");
  const target = join(root, "worktree");
  mkdirSync(source);
  function git(cwd: string, ...args: string[]) {
    return execFileSync("git", ["-C", cwd,
      "-c", "user.name=Test", "-c", "user.email=test@example.com",
      "-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null",
      "-c", "core.excludesFile=/dev/null", ...args], { encoding: "utf8", stdio: "pipe" });
  }
  git(source, "init");
  writeFileSync(join(source, ".gitignore"), ".envrc\n");
  git(source, "add", ".gitignore");
  git(source, "commit", "-m", "Initial");
  git(source, "worktree", "add", "-b", "test-worktree", target);
  writeFileSync(join(source, ".envrc"), "export PASEO_TEST_TOKEN=loaded\n");
  const workspace = {
    workspaceKind: "worktree" as const,
    worktreeSlug: "worktree",
    workspaceDirectory: target,
    projectRootPath: source,
  };
  return { root, source, target, workspace, git };
}

test("creates an idempotent bridge without copying credentials", async t => {
  const { source, target, workspace } = fixture(t);
  await Promise.all([ensureDirenv(workspace), ensureDirenv(workspace)]);
  const bridge = readFileSync(join(target, ".envrc"), "utf8");
  assert.match(bridge, /source_env '/);
  assert.ok(!bridge.includes("PASEO_TEST_TOKEN"));
  assert.equal(statSync(join(target, ".envrc")).mode & 0o777, 0o600);
  await ensureDirenv(workspace);
  assert.equal(readFileSync(join(target, ".envrc"), "utf8"), bridge);
  assert.ok(bridge.includes(source.replaceAll("'", "'\\''")));
});

test("requires explicit approval, then loads parent and relative imports from the original checkout", async t => {
  const { root, source, target, workspace } = fixture(t);
  writeFileSync(join(root, ".envrc"), "export PASEO_TEST_PARENT_TOKEN=parent\n");
  writeFileSync(join(source, "local.env"), "PASEO_TEST_TOKEN=local\n");
  writeFileSync(join(source, ".envrc"), "source_up\ndotenv local.env\n");
  await ensureDirenv(workspace);
  const env = {
    ...process.env, HOME: root, DIRENV_CONFIG: join(root, "direnv-config"),
    DIRENV_DIR: "", DIRENV_DIFF: "", DIRENV_WATCHES: "",
  };
  function inspect() {
    return execFileSync("direnv", ["exec", target, process.execPath, "-e",
      "process.stdout.write(JSON.stringify({token:process.env.PASEO_TEST_TOKEN,parent:process.env.PASEO_TEST_PARENT_TOKEN,cwd:process.cwd()}))"],
    { env, cwd: target, encoding: "utf8", stdio: "pipe" });
  }
  assert.throws(inspect, /blocked/);
  execFileSync("direnv", ["allow", target], { env, stdio: "pipe" });
  assert.deepEqual(JSON.parse(inspect()), { token: "local", parent: "parent", cwd: target });
});

test("preserves an existing worktree .envrc", async t => {
  const { target, workspace } = fixture(t);
  writeFileSync(join(target, ".envrc"), "export EXISTING=keep\n");
  await ensureDirenv(workspace);
  assert.equal(readFileSync(join(target, ".envrc"), "utf8"), "export EXISTING=keep\n");
});

test("preserves even a dangling worktree symlink", async t => {
  const { target, workspace } = fixture(t);
  symlinkSync("missing.envrc", join(target, ".envrc"));
  await ensureDirenv(workspace);
  assert.ok(lstatSync(join(target, ".envrc")).isSymbolicLink());
});

test("does not import a tracked source .envrc, even if an ignore rule matches", async t => {
  const { source, target, workspace, git } = fixture(t);
  git(source, "add", "-f", ".envrc");
  await ensureDirenv(workspace);
  assert.ok(!existsSync(join(target, ".envrc")));
});

test("does not recreate a tracked target .envrc deleted by the user", async t => {
  const { target, workspace, git } = fixture(t);
  writeFileSync(join(target, ".envrc"), "export TRACKED=yes\n");
  git(target, "add", "-f", ".envrc");
  rmSync(join(target, ".envrc"));
  await ensureDirenv(workspace);
  assert.ok(!existsSync(join(target, ".envrc")));
});

test("does not import an unignored source .envrc", async t => {
  const { source, target, workspace, git } = fixture(t);
  writeFileSync(join(source, ".gitignore"), "");
  // Override global excludes for the actual plugin subprocess too.
  git(source, "config", "core.excludesFile", "/dev/null");
  await ensureDirenv(workspace);
  assert.ok(!existsSync(join(target, ".envrc")));
});

test("does not create a bridge when the source .envrc is absent", async t => {
  const { source, target, workspace } = fixture(t);
  rmSync(join(source, ".envrc"));
  await ensureDirenv(workspace);
  assert.ok(!existsSync(join(target, ".envrc")));
});

test("leaves local checkouts and unmanaged worktrees alone", async t => {
  const { target, workspace } = fixture(t);
  await ensureDirenv({ ...workspace, workspaceKind: "local_checkout" });
  await ensureDirenv({ ...workspace, worktreeSlug: undefined });
  assert.ok(!existsSync(join(target, ".envrc")));
});

test("reports Git failures instead of treating them as an unignored file", async t => {
  const { root, workspace } = fixture(t);
  writeFileSync(join(root, ".envrc"), "export WRONG=source\n");
  await assert.rejects(ensureDirenv({ ...workspace, projectRootPath: root }), /not a git repository/);
});
