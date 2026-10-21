import assert from "node:assert/strict";
import { test } from "node:test";
import contribute from "../index.server.ts";

function register() {
  const events = new Map();
  const before = new Map();
  const dispose = contribute({
    on(name, callback) {
      events.set(name, callback);
      return () => events.delete(name);
    },
    before(name, callback) {
      before.set(name, callback);
      return () => before.delete(name);
    },
  });
  const fetched = [];
  const context = {
    paseo: {
      workspaces: {
        ref(id) {
          return {
            async refresh() {
              fetched.push(id);
              return null;
            },
          };
        },
      },
    },
  };
  return { events, before, dispose, fetched, context };
}

test("checks newly created workspaces and unregisters both hooks on cleanup", async () => {
  const { events, before, dispose, fetched, context } = register();
  await events.get("workspace.created")({ workspace: { id: "new-workspace" } }, context);
  assert.deepEqual(fetched, ["new-workspace"]);
  dispose();
  assert.equal(events.size, 0);
  assert.equal(before.size, 0);
});

test("checks all interactive launch reasons without changing launch configuration", async () => {
  const { before, fetched, context } = register();
  for (const reason of ["create", "resume", "refresh", "import"]) {
    const request = { workspaceId: reason, purpose: "interactive", reason, env: { KEEP: "unchanged" } };
    const original = structuredClone(request);
    assert.equal(await before.get("agent.session_open")({ request }, context), undefined);
    assert.deepEqual(request, original);
  }
  assert.deepEqual(fetched, ["create", "resume", "refresh", "import"]);
});

test("does not mutate environments or touch files during history-only and workspace-less opens", async () => {
  const { before, fetched, context } = register();
  for (const request of [
    { workspaceId: "history", purpose: "history" },
    { workspaceId: null, purpose: "interactive" },
  ]) {
    await before.get("agent.session_open")({ request }, context);
  }
  assert.deepEqual(fetched, []);
});
