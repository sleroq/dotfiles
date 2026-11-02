import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { existsSync, lstatSync, mkdirSync, mkdtempSync, readFileSync, readlinkSync, realpathSync, rmSync, statSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import type { TestContext } from "node:test";
import contribute from "../index.server.ts";
import { copyIgnoredFiles } from "./ignored-files.ts";

function fixture(t: TestContext) {
  const root = realpathSync(mkdtempSync(join(tmpdir(), "paseo-ignored-files-")));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const source = join(root, "repo with ' quotes $HOME");
  const target = join(root, "worktree");
  mkdirSync(source);
  function git(cwd: string, ...args: string[]) {
    return execFileSync("git", ["-C", cwd,
      "-c", "user.name=Test", "-c", "user.email=test@example.com",
      "-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null",
      ...args], { encoding: "utf8", stdio: "pipe" });
  }
  git(source, "init");
  git(source, "config", "core.excludesFile", "/dev/null");
  writeFileSync(join(source, ".gitignore"), ".env*\nconfig/*.local\nnode_modules/\n.direnv/\nbuild/\n");
  writeFileSync(join(source, "tracked.txt"), "committed\n");
  git(source, "add", ".");
  git(source, "commit", "-m", "Initial");
  git(source, "worktree", "add", "-b", "test-worktree", target);
  function write(file: string, content: string) {
    mkdirSync(dirname(join(source, file)), { recursive: true });
    writeFileSync(join(source, file), content);
  }
  return { root, source, target, git, write };
}

test("copies ignored config and build files while excluding dependency and direnv directories at every depth", async t => {
  const { source, target, write } = fixture(t);
  const files = {
    ".env": "SECRET=local\n",
    ".envrc": "dotenv .env\n",
    "config/app.local": "local config\n",
    "build/file with spaces\nand newline": "cache\n",
  };
  for (const [file, content] of Object.entries(files)) write(file, content);
  const excluded = ["node_modules/pkg/index.js", "packages/app/node_modules/pkg/index.js", ".direnv/cache", "packages/app/.direnv/cache"];
  for (const file of excluded) write(file, "not copied\n");
  write("unignored.txt", "not copied\n");
  write("tracked.txt", "dirty source\n");

  await copyIgnoredFiles(source, target);

  for (const [file, content] of Object.entries(files)) {
    assert.equal(readFileSync(join(target, file), "utf8"), content);
  }
  assert.equal(readFileSync(join(target, "tracked.txt"), "utf8"), "committed\n");
  assert.equal(existsSync(join(target, "unignored.txt")), false);
  for (const file of excluded) assert.equal(existsSync(join(target, file)), false);
});

test("supports a whitelist, exclusion precedence, and an empty include list", async t => {
  const { source, target, write } = fixture(t);
  write(".env", "selected\n");
  write(".env.secret", "excluded\n");
  write("build/cache", "not selected\n");
  write("config/app.local", "local config\n");

  await copyIgnoredFiles(source, target, { include: [], exclude: [] });
  assert.equal(existsSync(join(target, ".env")), false);
  await copyIgnoredFiles(source, target, { include: ["**/.env*", "config/*.local"], exclude: ["**/.env.secret"] });

  assert.equal(readFileSync(join(target, ".env"), "utf8"), "selected\n");
  assert.equal(readFileSync(join(target, "config/app.local"), "utf8"), "local config\n");
  for (const file of [".env.secret", "build/cache"]) {
    assert.equal(existsSync(join(target, file)), false);
  }
});

test("excludes dependency and direnv symlinks as well as directories", async t => {
  const { root, source, target } = fixture(t);
  symlinkSync(root, join(source, "node_modules"));
  symlinkSync("missing", join(source, ".direnv"));

  await copyIgnoredFiles(source, target);

  assert.equal(lstatSync(join(target, "node_modules"), { throwIfNoEntry: false }), undefined);
  assert.equal(lstatSync(join(target, ".direnv"), { throwIfNoEntry: false }), undefined);
});

test("honors local and global ignores but never copies tracked source files", async t => {
  const { root, source, target, git, write } = fixture(t);
  write(".env.tracked", "tracked source\n");
  git(source, "add", "-f", ".env.tracked");
  writeFileSync(join(source, ".git/info/exclude"), "local-secret\n");
  const excludes = join(root, "global-ignore");
  writeFileSync(excludes, "global-secret\n");
  git(source, "config", "core.excludesFile", excludes);
  write("local-secret", "local\n");
  write("global-secret", "global\n");

  await copyIgnoredFiles(source, target);

  assert.equal(existsSync(join(target, ".env.tracked")), false);
  assert.equal(readFileSync(join(target, "local-secret"), "utf8"), "local\n");
  assert.equal(readFileSync(join(target, "global-secret"), "utf8"), "global\n");
});

test("preserves existing target files and dangling symlinks, including on repeated copies", async t => {
  const { source, target, write } = fixture(t);
  write(".env", "source\n");
  write(".envrc", "source\n");
  writeFileSync(join(target, ".env"), "keep\n");
  symlinkSync("missing.envrc", join(target, ".envrc"));

  await copyIgnoredFiles(source, target);
  await copyIgnoredFiles(source, target);

  assert.equal(readFileSync(join(target, ".env"), "utf8"), "keep\n");
  assert.equal(readlinkSync(join(target, ".envrc")), "missing.envrc");
});

test("copies symlinks verbatim and preserves file permissions", async t => {
  const { source, target, write } = fixture(t);
  write("node_modules/pkg/index.js", "dependency\n");
  symlinkSync("pkg", join(source, "node_modules/linked"));
  symlinkSync("missing", join(source, "node_modules/dangling"));
  writeFileSync(join(source, ".env"), "SECRET=private\n", { mode: 0o600 });

  await copyIgnoredFiles(source, target, { include: ["**/*"], exclude: [] });

  assert.equal(readlinkSync(join(target, "node_modules/linked")), "pkg");
  assert.equal(readlinkSync(join(target, "node_modules/dangling")), "missing");
  assert.equal(statSync(join(target, ".env")).mode & 0o777, 0o600);
});

test("does not write through a target parent symlink from another branch", async t => {
  const { root, source, target, write } = fixture(t);
  const outside = join(root, "outside");
  mkdirSync(outside);
  write("config/app.local", "secret\n");
  symlinkSync(outside, join(target, "config"));

  await assert.rejects(copyIgnoredFiles(source, target), /non-directory/);

  assert.equal(existsSync(join(outside, "app.local")), false);
  assert.equal(lstatSync(join(target, "config")).isSymbolicLink(), true);
});

test("copies from the supplied source worktree, not the main checkout", async t => {
  const { root, source, target, git, write } = fixture(t);
  write(".env", "MAIN=source\n");
  writeFileSync(join(target, ".env"), "WORKTREE=source\n");
  const nested = join(root, "nested-worktree");
  git(source, "worktree", "add", "-b", "nested", nested);

  await copyIgnoredFiles(target, nested);

  assert.equal(readFileSync(join(nested, ".env"), "utf8"), "WORKTREE=source\n");
});

test("reports Git and nested-repository copy failures", async t => {
  const { root, source, target, git } = fixture(t);
  await assert.rejects(copyIgnoredFiles(root, target), /not a git repository/);
  git(source, "init", "build/nested-repo");
  await assert.rejects(copyIgnoredFiles(source, target), /directory/);
  assert.equal(existsSync(join(target, "build/nested-repo/.git")), false);
});

test("registers one awaited creation hook, propagates failures, and unregisters on cleanup", async t => {
  const { root, source, target, write } = fixture(t);
  write(".env", "READY=before-setup\n");
  let hookName: string | undefined;
  let hook: ((event: { worktree: { sourceCheckout: string; path: string } }) => Promise<void>) | undefined;
  let removed = false;
  // SAFETY: contribute only calls addHook; this fixture implements its callback and cleanup contract.
  const dispose = contribute({
    addHook(name: string, callback: NonNullable<typeof hook>) {
      hookName = name;
      hook = callback;
      return () => { removed = true; };
    },
  } as Parameters<typeof contribute>[0]);

  assert.equal(hookName, "worktree.create.after");
  await hook!({ worktree: { sourceCheckout: source, path: target } });
  assert.equal(readFileSync(join(target, ".env"), "utf8"), "READY=before-setup\n");
  await assert.rejects(hook!({ worktree: { sourceCheckout: root, path: target } }), /not a git repository/);
  dispose();
  assert.equal(removed, true);
});
