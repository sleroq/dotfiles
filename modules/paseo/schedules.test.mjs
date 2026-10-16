import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { syncSchedules } from "./schedules.mjs";

const definition = {
  adoptId: null,
  name: "Daily review",
  prompt: "Review outstanding tasks.\n",
  cron: "0 9 * * *",
  timezone: "UTC",
  provider: "pi",
  model: "openai/gpt-6.1-sol",
  modeId: null,
  thinkingOptionId: "low",
  cwd: "/home/paseo/projects/dotfiles",
  archiveOnFinish: true,
  isolation: "local",
  maxRuns: null,
  expiresAt: null,
};

function storedSchedule(id, overrides = {}) {
  return {
    id,
    name: definition.name,
    prompt: definition.prompt.trim(),
    cadence: { type: "cron", expression: definition.cron, timezone: "UTC" },
    target: {
      type: "new-agent",
      config: {
        provider: definition.provider,
        model: definition.model,
        thinkingOptionId: definition.thinkingOptionId,
        cwd: definition.cwd,
        archiveOnFinish: true,
        isolation: "local",
      },
    },
    status: "paused",
    nextRunAt: null,
    pausedAt: "2026-10-16T00:00:00.000Z",
    runs: [{ id: "previous-run", status: "succeeded" }],
    maxRuns: null,
    expiresAt: null,
    ...overrides,
  };
}

function fakeClient(initial = []) {
  const schedules = new Map(initial.map(schedule => [schedule.id, structuredClone(schedule)]));
  const calls = [];

  return {
    schedules,
    calls,
    async scheduleList() {
      return { schedules: structuredClone([...schedules.values()]), error: null };
    },
    async scheduleCreate(input) {
      calls.push(["create", input]);
      const schedule = storedSchedule(`created-${schedules.size}`, {
        ...input,
        status: "active",
        pausedAt: null,
        runs: [],
        maxRuns: input.maxRuns ?? null,
        expiresAt: input.expiresAt ?? null,
      });
      schedules.set(schedule.id, schedule);
      return { schedule, error: null };
    },
    async scheduleUpdate(input) {
      calls.push(["update", input]);
      const schedule = schedules.get(input.id);
      const { id, newAgentConfig, ...fields } = input;
      Object.assign(schedule, fields);
      for (const [key, value] of Object.entries(newAgentConfig ?? {})) {
        if (value === null) {
          delete schedule.target.config[key];
        } else {
          schedule.target.config[key] = value;
        }
      }
      return { schedule, error: null };
    },
    async scheduleDelete(input) {
      calls.push(["delete", input]);
      schedules.delete(input.id);
      return { scheduleId: input.id, error: null };
    },
  };
}

async function stateFile(t, initial) {
  const directory = await mkdtemp(join(tmpdir(), "paseo-schedules-"));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const path = join(directory, "managed.json");
  if (initial) {
    await writeFile(path, JSON.stringify(initial));
  }
  return path;
}

async function ownership(path) {
  return JSON.parse(await readFile(path, "utf8"));
}

test("adopts an existing schedule without mutations, preserving pause and history", async t => {
  const state = await stateFile(t);
  const current = storedSchedule("existing");
  const client = fakeClient([current]);
  await syncSchedules({ review: { ...definition, adoptId: "existing" } }, state, client);
  assert.deepEqual(client.calls, []);
  assert.deepEqual(await ownership(state), { review: "existing" });
  assert.deepEqual(client.schedules.get("existing"), current);
});

test("creates once without firing and leaves app-created schedules alone", async t => {
  const state = await stateFile(t);
  const client = fakeClient([storedSchedule("manual")]);
  await syncSchedules({ review: definition }, state, client);
  const [[operation, input]] = client.calls;
  assert.equal(operation, "create");
  assert.equal(input.runOnCreate, false);
  assert.equal(input.target.config.thinkingOptionId, "low");
  assert.equal(Object.hasOwn(input.target.config, "modeId"), false);
  assert.equal(input.maxRuns, undefined);
  assert.equal(input.expiresAt, undefined);
  await syncSchedules({ review: definition }, state, client);
  assert.equal(client.calls.length, 1);
  assert.deepEqual(await ownership(state), { review: "created-1" });
  assert.equal(client.schedules.has("manual"), true);
});

test("updates all changed definition fields without touching cadence or runtime state", async t => {
  const state = await stateFile(t, { review: "existing" });
  const client = fakeClient([storedSchedule("existing", { maxRuns: 3, expiresAt: "2027-01-01T00:00:00.000Z" })]);
  const next = {
    ...definition,
    name: "Renamed review",
    prompt: "New prompt.\n",
    provider: "codex",
    model: null,
    modeId: "full-access",
    thinkingOptionId: null,
    archiveOnFinish: false,
    isolation: "worktree",
    cwd: "/another/project",
  };
  await syncSchedules({ review: next }, state, client);
  assert.deepEqual(client.calls, [["update", {
    id: "existing",
    name: "Renamed review",
    prompt: "New prompt.",
    maxRuns: null,
    expiresAt: null,
    newAgentConfig: {
      provider: "codex",
      cwd: "/another/project",
      model: null,
      modeId: "full-access",
      thinkingOptionId: null,
      archiveOnFinish: false,
      isolation: "worktree",
    },
  }]]);
  const current = client.schedules.get("existing");
  assert.equal(current.status, "paused");
  assert.equal(current.runs[0].id, "previous-run");
  await syncSchedules({ review: next }, state, client);
  assert.equal(client.calls.length, 1);
});

test("updates cadence only when its definition changes", async t => {
  const state = await stateFile(t, { review: "existing" });
  const client = fakeClient([storedSchedule("existing")]);
  const next = { ...definition, cron: "0 10 * * *", timezone: "Europe/Berlin" };
  await syncSchedules({ review: next }, state, client);
  assert.deepEqual(client.calls, [["update", {
    id: "existing",
    cadence: { type: "cron", expression: next.cron, timezone: next.timezone },
  }]]);
});

test("removes the final owned schedule with an empty declaration, not unmanaged schedules", async t => {
  const state = await stateFile(t, { review: "existing" });
  const client = fakeClient([storedSchedule("existing"), storedSchedule("manual")]);
  await syncSchedules({}, state, client);
  assert.deepEqual(client.calls, [["delete", { id: "existing" }]]);
  assert.deepEqual(await ownership(state), {});
  assert.equal(client.schedules.has("manual"), true);
  await syncSchedules({}, state, client);
  assert.equal(client.calls.length, 1);
});

test("recreates a deleted managed schedule and uses its new ID on future deployments", async t => {
  const state = await stateFile(t, { review: "deleted" });
  const client = fakeClient();
  const definitions = { review: { ...definition, adoptId: "deleted" } };
  await syncSchedules(definitions, state, client);
  assert.deepEqual(await ownership(state), { review: "created-0" });
  await syncSchedules(definitions, state, client);
  assert.equal(client.calls.length, 1);
});

test("forgets a removed ownership entry even when its schedule was already deleted", async t => {
  const state = await stateFile(t, { review: "deleted" });
  const client = fakeClient();
  await syncSchedules({}, state, client);
  assert.deepEqual(await ownership(state), {});
  assert.deepEqual(client.calls, []);
});

test("recognizes implicit provider defaults without writing redundant patches", async t => {
  const state = await stateFile(t, { review: "existing" });
  const current = storedSchedule("existing");
  delete current.target.config.archiveOnFinish;
  delete current.target.config.isolation;
  const client = fakeClient([current]);
  await syncSchedules({ review: definition }, state, client);
  assert.deepEqual(client.calls, []);
});

test("does not prune ownership after a failed deletion", async t => {
  const state = await stateFile(t, { review: "existing" });
  const client = fakeClient([storedSchedule("existing")]);
  client.scheduleDelete = async () => ({ error: "permission denied" });
  await assert.rejects(syncSchedules({}, state, client), /permission denied/);
  assert.deepEqual(await ownership(state), { review: "existing" });
});

test("propagates connection errors without pruning existing schedules", async t => {
  const state = await stateFile(t, { review: "existing" });
  const client = fakeClient([storedSchedule("existing")]);
  client.scheduleCreate = async () => { throw new Error("connection lost"); };
  await assert.rejects(syncSchedules({ new: definition }, state, client), /connection lost/);
  assert.deepEqual(await ownership(state), { review: "existing" });
  assert.equal(client.schedules.has("existing"), true);
});

test("does not adopt heartbeats or other existing-agent targets", async t => {
  const state = await stateFile(t);
  const client = fakeClient([storedSchedule("heartbeat", { target: { type: "agent", agentId: "agent" } })]);
  await assert.rejects(syncSchedules({ review: { ...definition, adoptId: "heartbeat" } }, state, client), /non-new-agent/);
  assert.deepEqual(client.calls, []);
});

test("rejects corrupt ownership rather than treating managed schedules as unowned", async t => {
  const state = await stateFile(t);
  await writeFile(state, "not json");
  const client = fakeClient();
  await assert.rejects(syncSchedules({}, state, client), SyntaxError);
  assert.deepEqual(client.calls, []);
});
