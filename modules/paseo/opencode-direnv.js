import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

async function applyDirenv(cwd, env) {
  const { stdout } = await execFileAsync("direnv", ["export", "json"], {
    cwd,
    env: { ...process.env, ...env },
  });
  if (!stdout.trim()) return;
  const changes = JSON.parse(stdout);
  for (const [name, value] of Object.entries(changes)) {
    if (value === null) delete env[name];
    else env[name] = value;
  }
}

export default {
  id: "direnv",
  async setup(ctx) {
    await ctx.shell.hook("create.before", ({ cwd, env }) => applyDirenv(cwd, env));
  },
};
