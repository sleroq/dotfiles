import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import type { BeforeAgentStartEvent } from "@earendil-works/pi-coding-agent";
import { appendOkabePrompt } from "./index";

const prompt = readFileSync(new URL("./okabe-system-prompt.md", import.meta.url), "utf8").trim();

function startEvent(systemPrompt: string): BeforeAgentStartEvent {
  return {
    type: "before_agent_start",
    messageType: "user",
    prompt: "Reply OK",
    systemPrompt,
    systemPromptOptions: {
      cwd: process.cwd(),
      selectedTools: [],
      hiddenTools: [],
      toolSnippets: {},
      toolGuidelines: {},
      promptGuidelines: [],
      appendSystemPrompt: "",
      sections: { preamble: systemPrompt },
      contextFiles: [],
      skills: [],
    },
  };
}

test("keeps Okabe in the parent before and after an in-process child run", () => {
  const parent = startEvent("You are an expert coding assistant.");
  const child = startEvent(`${parent.systemPrompt}\n\n<active_agent name="suzuha"/>\n\nYou are Suzuha.`);
  appendOkabePrompt(parent);
  appendOkabePrompt(child);
  const nextParent = startEvent(parent.systemPrompt);
  appendOkabePrompt(nextParent);

  expect(parent.systemPromptOptions.sections.okabe).toBe(prompt);
  expect(Object.keys(child.systemPromptOptions.sections)).toEqual(["preamble"]);
  expect(nextParent.systemPromptOptions.sections.okabe).toBe(prompt);
});

for (const name of ["suzuha", "itaru", "kristina", "Explore", "general-purpose"]) {
  test(`does not append Okabe to ${name}'s own prompt`, () => {
    const event = startEvent(`Inherited identity\n\n<active_agent name="${name}"/>\n\nSpecialist instructions`);
    appendOkabePrompt(event);
    expect(Object.keys(event.systemPromptOptions.sections)).toEqual(["preamble"]);
    expect(event.systemPromptOptions.sections.preamble).toBe(event.systemPrompt);
  });
}
