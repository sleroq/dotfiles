import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

export default async function direnvPlugin() {
  return {
    "shell.env": async ({ cwd }, { env }) => {
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
    },
  };
}
