import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  let enabled = false;
  pi.on("session_start", () => { enabled = false; });

  pi.registerCommand("fast", {
    description: "Toggle OpenAI subscription Fast mode: /fast [on|off]",
    handler: async (args, ctx) => {
      if (args !== "" && args !== "on" && args !== "off") {
        ctx.ui.notify("Usage: /fast [on|off]", "warning");
        return;
      }
      enabled = args === "" ? !enabled : args === "on";
      ctx.ui.notify(`Fast mode ${enabled ? "on (higher subscription usage)" : "off"}.`, "info");
    },
  });

  pi.on("before_provider_request", (event, ctx) => {
    const model = ctx.model;
    if (!enabled || !model) return;
    const subscription = model.provider === "openai-codex" ||
      (model.provider === "openai" && model.api === "openai-responses" && ctx.modelRegistry.isUsingOAuth(model));
    if (subscription) return Object.assign({}, event.payload, { service_tier: "priority" });
  });
}
