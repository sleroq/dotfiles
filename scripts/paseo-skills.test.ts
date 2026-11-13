import { expect, test } from "bun:test";
import { homedir } from "node:os";
import { join } from "node:path";
import paseoSkills from "../home/config/pi/agent/extensions/paseo-skills";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

type DiscoverHandler = () => { skillPaths: string[] } | undefined;

test("discovers Paseo skills only in a Paseo agent", () => {
  let discover: DiscoverHandler;
  // SAFETY: This extension only registers a resources_discover handler on the API.
  paseoSkills({ on: (event: string, handler: DiscoverHandler) => {
    expect(event).toBe("resources_discover");
    discover = handler;
  } } as ExtensionAPI);
  const previous = process.env.PASEO_AGENT_ID;
  try {
    delete process.env.PASEO_AGENT_ID;
    expect(discover()).toBeUndefined();
    process.env.PASEO_AGENT_ID = "agent-id";
    expect(discover()).toEqual({ skillPaths: [join(homedir(), ".pi/paseo-skills")] });
  } finally {
    if (previous === undefined) delete process.env.PASEO_AGENT_ID;
    else process.env.PASEO_AGENT_ID = previous;
  }
});
