import type { PluginServerContext } from "@getpaseo/plugin/server";
import { copyIgnoredFiles } from "./server/ignored-files.ts";

export default function contribute(server: PluginServerContext) {
  return server.addHook("worktree.create.after", async ({ worktree }) => {
    await copyIgnoredFiles(worktree.sourceCheckout, worktree.path);
  });
}
