import type { PluginServerContext } from "@getpaseo/plugin/server";
import { publishCacheMisses } from "./server/monitor.ts";

export default function contribute(server: PluginServerContext) {
  const turnStarts = new Map<string, number>();
  const removeStart = server.addHook("agent.turn.before", async ({ agent }) => {
    if (agent.provider === "pi") turnStarts.set(agent.id, Date.now());
  });
  const removeEnd = server.addHook("agent.turn.after", async ({ agent }, { paseo }) => {
    const since = turnStarts.get(agent.id);
    turnStarts.delete(agent.id);
    if (agent.provider !== "pi" || since === undefined) return;
    await publishCacheMisses(paseo.agents.ref(agent.id), since);
  });
  return () => {
    removeStart();
    removeEnd();
    turnStarts.clear();
  };
}
