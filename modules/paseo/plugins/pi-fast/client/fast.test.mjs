import assert from "node:assert/strict";
import { test } from "node:test";
import contribute from "../index.client.ts";

function setup() {
  const pills = new Map();
  const sent = [];
  const failures = { commands: null, send: null };
  let commands = [{ name: "fast" }];
  let observer;
  let signal;

  const stop = contribute({
    paseo: { agents: {
      list: async (options) => {
        signal = options.signal;
        return { subscription: { subscribe: (callbacks) => { observer = callbacks; } } };
      },
      ref: (id) => ({
        commands: async () => ({ commands, error: failures.commands }),
        send: async (text) => {
          if (failures.send) throw failures.send;
          sent.push({ id, text });
        },
      }),
    } },
    addComposerPill: (contribution) => {
      assert.equal(pills.has(contribution.agentId), false, "no duplicate registration");
      const button = { ...contribution.button };
      const registration = {
        ...contribution, button,
        update: (patch) => Object.assign(button, patch),
        remove: () => pills.delete(contribution.agentId),
      };
      pills.set(contribution.agentId, registration);
      return registration;
    },
  });

  const agent = (overrides = {}) => ({
    id: "pi-agent", provider: "pi", workspaceId: "workspace", status: "idle", ...overrides,
  });
  return {
    pills, sent, failures, stop, agent,
    ready: async () => { await Promise.resolve(); },
    snapshot: (...agents) => observer.snapshot({ entries: agents.map((agent) => ({ agent })) }),
    upsert: (agent) => observer.update({ type: "agent_update", payload: { kind: "upsert", agent } }),
    remove: (agentId) => observer.update({ type: "agent_update", payload: { kind: "remove", agentId } }),
    setCommands: (next) => { commands = next; },
    isAborted: () => signal.aborted,
  };
}

function action(pill, id) {
  return pill.button.behavior.items.find((item) => item.id === id).behavior.onPress;
}

test("adds only Pi composer menus, without sending anything or claiming a state", async () => {
  const ui = setup();
  await ui.ready();
  ui.snapshot(ui.agent(), ui.agent({ id: "codex", provider: "codex" }),
    ui.agent({ id: "no-workspace", workspaceId: undefined }),
    ui.agent({ id: "archived", archivedAt: "2026-10-24" }));
  assert.equal(ui.pills.size, 1);
  const pill = ui.pills.get("pi-agent");
  assert.equal(pill.workspaceId, "workspace");
  assert.equal(pill.button.label, "Fast");
  assert.equal(pill.button.icon, "Zap");
  assert.equal(pill.button.disabled, false);
  assert.deepEqual(ui.sent, []);
  ui.stop();
});

test("Enable and Disable send explicit commands to the selected agent", async () => {
  const ui = setup();
  await ui.ready();
  ui.snapshot(ui.agent());
  const pill = ui.pills.get("pi-agent");
  await action(pill, "enable")();
  await action(pill, "disable")();
  assert.deepEqual(ui.sent, [{ id: "pi-agent", text: "/fast on" }, { id: "pi-agent", text: "/fast off" }]);
  ui.stop();
});

test("updates busy state in place and removes pills when agents leave", async () => {
  const ui = setup();
  await ui.ready();
  ui.snapshot(ui.agent());
  const pill = ui.pills.get("pi-agent");
  for (const status of ["running", "initializing", "idle"]) {
    ui.upsert(ui.agent({ status }));
    assert.equal(ui.pills.get("pi-agent"), pill);
    assert.equal(pill.button.disabled, status !== "idle");
  }
  ui.upsert(ui.agent({ provider: "codex" }));
  assert.equal(ui.pills.size, 0);
  ui.upsert(ui.agent());
  ui.upsert(ui.agent({ archivedAt: "2026-10-24" }));
  assert.equal(ui.pills.size, 0);
  ui.upsert(ui.agent());
  ui.remove("pi-agent");
  assert.equal(ui.pills.size, 0);
  ui.stop();
});

test("moves menus with agents and replaces stale snapshots after reconnect", async () => {
  const ui = setup();
  await ui.ready();
  ui.snapshot(ui.agent());
  ui.upsert(ui.agent({ workspaceId: "another-workspace" }));
  assert.equal(ui.pills.get("pi-agent").workspaceId, "another-workspace");
  ui.snapshot(ui.agent({ id: "another-agent" }));
  assert.deepEqual([...ui.pills.keys()], ["another-agent"]);
  ui.stop();
  assert.equal(ui.pills.size, 0);
  assert.equal(ui.isAborted(), true);
});

test("missing /fast never becomes an unintended model prompt", async () => {
  const ui = setup();
  await ui.ready();
  ui.snapshot(ui.agent());
  ui.setCommands([]);
  await assert.rejects(action(ui.pills.get("pi-agent"), "enable"), /Reload Pi/);
  assert.deepEqual(ui.sent, []);
  ui.stop();
});

test("surfaces command-discovery and delivery errors to Paseo", async () => {
  const ui = setup();
  await ui.ready();
  ui.snapshot(ui.agent());
  const enable = action(ui.pills.get("pi-agent"), "enable");
  ui.failures.commands = "Pi session unavailable";
  await assert.rejects(enable, /Pi session unavailable/);
  assert.deepEqual(ui.sent, []);
  ui.failures.commands = null;
  ui.failures.send = new Error("Disconnected");
  await assert.rejects(enable, /Disconnected/);
  ui.stop();
});
