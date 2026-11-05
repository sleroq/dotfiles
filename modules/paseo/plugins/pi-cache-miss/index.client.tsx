import type { PluginClientContext } from "@getpaseo/plugin/client";
import { CacheMissWarning } from "./client/cache-miss.tsx";
import { cacheMissSchema } from "./shared/cache-miss.ts";

export default function contribute(client: PluginClientContext) {
  return client.addTimelineRenderer({
    kind: "cache-miss",
    version: 1,
    schema: cacheMissSchema,
    Component: CacheMissWarning,
  });
}
