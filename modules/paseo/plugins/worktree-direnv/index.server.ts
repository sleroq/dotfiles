import type { PluginHookContext, PluginServerContext } from "@getpaseo/plugin/server";
import { ensureDirenv } from "./server/direnv.ts";

export default function contribute(server: PluginServerContext) {
  async function prepareWorkspace(id: string, { paseo }: PluginHookContext) {
    const workspace = await paseo.workspaces.ref(id).refresh();
    if (workspace) await ensureDirenv(workspace);
  }

  const removeCreated = server.on("workspace.created", ({ workspace }, context) =>
    prepareWorkspace(workspace.id, context));

  const removeSessionOpen = server.before("agent.session_open", async ({ request }, context) => {
    if (request.workspaceId && request.purpose === "interactive") {
      await prepareWorkspace(request.workspaceId, context);
    }
  });

  return () => {
    removeCreated();
    removeSessionOpen();
  };
}
