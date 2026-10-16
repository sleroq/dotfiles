import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname } from "node:path";
import { pathToFileURL } from "node:url";
import { isDeepStrictEqual } from "node:util";

function scheduleDefinition(definition) {
  const {
    name, prompt, cron, timezone, provider, cwd, model, modeId,
    thinkingOptionId, archiveOnFinish, isolation, maxRuns, expiresAt,
  } = definition;
  return {
    name: name.trim(),
    prompt: prompt.trim(),
    cadence: { type: "cron", expression: cron, timezone },
    maxRuns,
    expiresAt,
    newAgentConfig: {
      provider, cwd, model, modeId, thinkingOptionId, archiveOnFinish, isolation,
    },
  };
}

function changedFields(current, desired) {
  return Object.fromEntries(Object.entries(desired).filter(
    ([key, value]) => !isDeepStrictEqual(current[key], value),
  ));
}

function schedulePatch(current, desired) {
  if (current.target.type !== "new-agent") {
    throw new Error(`Cannot adopt non-new-agent schedule ${current.id}`);
  }
  const { newAgentConfig, ...fields } = desired;
  const patch = changedFields(current, fields);
  const configPatch = changedFields({
    model: null,
    modeId: null,
    thinkingOptionId: null,
    archiveOnFinish: true,
    isolation: "local",
    ...current.target.config,
  }, newAgentConfig);
  if (Object.keys(configPatch).length) {
    patch.newAgentConfig = configPatch;
  }
  return patch;
}

async function response(request) {
  const result = await request;
  if (result.error) {
    throw new Error(result.error);
  }
  return result;
}

async function readOwnership(statePath) {
  try {
    return JSON.parse(await readFile(statePath, "utf8"));
  } catch (error) {
    if (error.code !== "ENOENT") {
      throw error;
    }
    return {};
  }
}

async function saveOwnership(statePath, owned) {
  await mkdir(dirname(statePath), { recursive: true, mode: 0o700 });
  const temporary = `${statePath}.tmp`;
  await writeFile(temporary, `${JSON.stringify(owned, null, 2)}\n`, { mode: 0o600 });
  await rename(temporary, statePath);
}

export async function syncSchedules(definitions, statePath, client) {
  const owned = await readOwnership(statePath);
  const { schedules } = await response(client.scheduleList());
  const currentById = new Map(schedules.map(schedule => [schedule.id, schedule]));

  for (const [key, definition] of Object.entries(definitions)) {
    const desired = scheduleDefinition(definition);
    const current = currentById.get(owned[key] ?? definition.adoptId);
    let id;
    if (current) {
      id = current.id;
      const patch = schedulePatch(current, desired);
      if (Object.keys(patch).length) {
        await response(client.scheduleUpdate({ id, ...patch }));
        console.log(`Updated ${key} (${id})`);
      }
    } else {
      const { newAgentConfig, ...fields } = desired;
      // Create rejects null optional fields; updates use null to clear them.
      const config = Object.fromEntries(Object.entries(newAgentConfig).filter(
        ([, value]) => value !== null,
      ));
      const { schedule } = await response(client.scheduleCreate({
        ...fields,
        maxRuns: fields.maxRuns ?? undefined,
        expiresAt: fields.expiresAt ?? undefined,
        target: { type: "new-agent", config },
        runOnCreate: false,
      }));
      id = schedule.id;
      console.log(`Created ${key} (${id})`);
    }
    if (owned[key] !== id) {
      owned[key] = id;
      await saveOwnership(statePath, owned);
    }
  }

  for (const [key, id] of Object.entries(owned)) {
    if (Object.hasOwn(definitions, key)) {
      continue;
    }
    if (currentById.has(id)) {
      await response(client.scheduleDelete({ id }));
      console.log(`Deleted ${key} (${id})`);
    }
    delete owned[key];
    await saveOwnership(statePath, owned);
  }
}

if (import.meta.main) {
  const [definitionsPath, statePath, clientModule, home] = process.argv.slice(2);
  // Reuse the pinned CLI's connection/authentication plumbing. Its public
  // facade does not expose schedules; keep this version-coupled boundary here.
  const { connectToDaemon } = await import(pathToFileURL(clientModule).href);
  const definitions = JSON.parse(await readFile(definitionsPath, "utf8"));
  const client = await connectToDaemon({ target: { kind: "instance", home } });
  try {
    await syncSchedules(definitions, statePath, client);
  } finally {
    await client.close();
  }
}
