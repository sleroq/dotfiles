import { execFile } from "node:child_process"
import { promisify } from "node:util"

import { Plugin } from "@opencode/plugin"

type ShellEnvironment = Record<string, string | undefined>

const execFileAsync = promisify(execFile)

async function applyDirenv(cwd: string, env: ShellEnvironment) {
  const { stdout } = await execFileAsync("direnv", ["export", "json"], {
    cwd,
    env,
  })

  let diff: unknown
  try {
    diff = JSON.parse(stdout.toString())
  } catch (cause) {
    throw new Error(`direnv export emitted invalid JSON in ${cwd}`, { cause })
  }

  if (diff === null || typeof diff !== "object" || Array.isArray(diff)) {
    throw new Error(`direnv export emitted non-object JSON in ${cwd}`)
  }

  for (const [key, value] of Object.entries(diff)) {
    if (typeof value === "string") env[key] = value
    if (value === null) delete env[key]
  }
}

export default Plugin.define({
  id: "direnv",
  async setup(ctx) {
    await ctx.shell.hook("create.before", (event) =>
      applyDirenv(event.cwd, event.env),
    )
  },
})
