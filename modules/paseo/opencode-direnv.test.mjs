import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import direnvPlugin from "./opencode-direnv.js";

async function createHook() {
  let hook;
  await direnvPlugin.setup({
    shell: {
      hook: async (name, callback) => {
        assert.equal(name, "create.before");
        hook = callback;
      },
    },
  });
  return hook;
}

test("OpenCode shell environments handle plain, trusted and blocked projects", async () => {
  const root = mkdtempSync(join(tmpdir(), "paseo-direnv-"));
  const env = {
    HOME: root,
    PATH: process.env.PATH,
    DIRENV_CONFIG: join(root, "config"),
    DIRENV_DIR: "",
    DIRENV_DIFF: "",
    DIRENV_WATCHES: "",
    KEEP: "unchanged",
  };
  try {
    const hook = await createHook();
    const plain = { ...env };
    await hook({ cwd: root, env });
    assert.deepEqual(env, plain);

    for (const name of ["first", "second", "blocked"]) {
      const cwd = join(root, name);
      mkdirSync(cwd);
      writeFileSync(join(cwd, ".envrc"), `export PASEO_${name.toUpperCase()}=loaded\n`);
      if (name === "blocked") {
        await assert.rejects(hook({ cwd, env }), /blocked/);
        continue;
      }
      execFileSync("direnv", ["allow", cwd], { env });
      await hook({ cwd, env });
      assert.equal(env[`PASEO_${name.toUpperCase()}`], "loaded");
    }
    assert.equal(env.PASEO_FIRST, undefined);
    await hook({ cwd: root, env });
    assert.equal(env.PASEO_SECOND, undefined);
    assert.equal(env.KEEP, "unchanged");
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
