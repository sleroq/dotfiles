import type { PaseoAgent } from "@getpaseo/client";
import type { PluginButtonRegistration, PluginClientContext } from "@getpaseo/plugin/client";

export default function contribute(client: PluginClientContext) {
  const lifetime = new AbortController();
  const pills = new Map<string, { workspaceId: string; pill: PluginButtonRegistration }>();

  function remove(agentId: string) {
    pills.get(agentId)?.pill.remove();
    pills.delete(agentId);
  }

  function syncAgent(agent: PaseoAgent) {
    if (agent.provider !== "pi" || !agent.workspaceId || agent.archivedAt) {
      remove(agent.id);
      return;
    }
    const disabled = agent.status === "running" || agent.status === "initializing";
    const existing = pills.get(agent.id);
    if (existing?.workspaceId === agent.workspaceId) {
      existing.pill.update({ disabled });
      return;
    }
    remove(agent.id);

    async function setFast(mode: "on" | "off") {
      const session = client.paseo.agents.ref(agent.id);
      const { commands, error } = await session.commands();
      if (error) throw new Error(error);
      if (!commands.some((command) => command.name === "fast")) {
        throw new Error("Pi's /fast command is unavailable. Reload Pi to load the local Fast extension.");
      }
      await session.send(`/fast ${mode}`);
    }

    const pill = client.addComposerPill({
      id: "fast",
      workspaceId: agent.workspaceId,
      agentId: agent.id,
      button: {
        title: "OpenAI subscription Fast mode",
        icon: "Zap",
        label: "Fast",
        disabled,
        behavior: {
          kind: "menu",
          items: [
            { kind: "item", id: "enable", title: "Enable Fast (higher usage)",
              behavior: { kind: "action", onPress: () => setFast("on") } },
            { kind: "item", id: "disable", title: "Disable Fast",
              behavior: { kind: "action", onPress: () => setFast("off") } },
          ],
        },
      },
    });
    pills.set(agent.id, { workspaceId: agent.workspaceId, pill });
  }

  function removeAll() {
    for (const agentId of pills.keys()) remove(agentId);
  }

  void client.paseo.agents.list({ subscribe: {}, signal: lifetime.signal }).then(({ subscription }) => {
    subscription.subscribe({
      snapshot: ({ entries }) => {
        removeAll();
        for (const { agent } of entries) syncAgent(agent);
      },
      update: (message) => {
        if (message.type !== "agent_update") return;
        const update = message.payload;
        if (update.kind === "upsert") syncAgent(update.agent);
        else remove(update.agentId);
      },
    });
  }).catch((error) => {
    if (!lifetime.signal.aborted) console.error("Fast menu agent observation failed", error);
  });

  return () => {
    lifetime.abort();
    removeAll();
  };
}
