import { expect, test } from "bun:test";
import { $ } from "bun";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { exportProfile } from "./deploy-pi-profile";
import { syncProfile } from "../modules/paseo/pi-profile.mjs";

const root = resolve(import.meta.dir, "..");

test("only the work profile proxies Pi and Exa and uses the private Exa file", async () => {
  const shared = await exportProfile(undefined, root);
  const work = await exportProfile(undefined, root, "work");
  const desktop = await exportProfile(undefined, root, "desktop");
  const sharedSettings = JSON.parse((await $`tar -xOf - ./pi/settings.json < ${shared.archive}`.quiet()).stdout.toString());
  const workSettings = JSON.parse((await $`tar -xOf - ./pi/settings.json < ${work.archive}`.quiet()).stdout.toString());

  expect(sharedSettings.httpProxy).toBeUndefined();
  expect(workSettings).toEqual({ ...sharedSettings, httpProxy: "http://127.0.0.1:2080" });
  expect(work.metadata.contentDigest).not.toBe(shared.metadata.contentDigest);
  expect(desktop.metadata.contentDigest).toBe(shared.metadata.contentDigest);

  const sharedMcp = JSON.parse((await $`tar -xOf - ./pi/mcp.json < ${shared.archive}`.quiet()).stdout.toString());
  const workMcp = JSON.parse((await $`tar -xOf - ./pi/mcp.json < ${work.archive}`.quiet()).stdout.toString());
  expect(sharedMcp.mcpServers.exa.env.EXA_API_KEY).toBe("${EXA_API_KEY}");
  expect(workMcp.mcpServers.exa.env).toEqual({
    ...sharedMcp.mcpServers.exa.env,
    EXA_API_KEY: '!. "$HOME/.config/pi/exa.env" && printf %s "$EXA_API_KEY"',
    HTTP_PROXY: "http://127.0.0.1:2080",
    HTTPS_PROXY: "http://127.0.0.1:2080",
    NO_PROXY: "",
    NODE_USE_ENV_PROXY: "1",
  });
  const entries = (await $`tar -tf - < ${work.archive}`.quiet()).stdout.toString();
  expect(entries).not.toContain("exa.env");
  expect(entries).not.toContain("shared/secrets");
});

test.each(["${EXA_API_KEY}", "host-local-test-key"])("migrates the old Exa placeholder but preserves explicit host keys: %s", async (key) => {
  const directory = mkdtempSync(join(tmpdir(), "pi-exa-sync-"));
  try {
    const command = '!. "$HOME/.config/pi/exa.env" && printf %s "$EXA_API_KEY"';
    const settings = join(directory, "defaults-settings.json");
    const mcp = join(directory, "defaults-mcp.json");
    writeFileSync(settings, "{}");
    writeFileSync(mcp, JSON.stringify({ mcpServers: { exa: { env: {
      EXA_API_KEY: command,
      HTTPS_PROXY: "http://127.0.0.1:2080",
      NODE_USE_ENV_PROXY: "1",
    } } } }));
    writeFileSync(join(directory, "mcp.json"), JSON.stringify({ mcpServers: { exa: { env: {
      EXA_API_KEY: key,
      HTTPS_PROXY: "http://old-proxy.invalid",
      NODE_USE_ENV_PROXY: "0",
    } } } }));

    await syncProfile(settings, mcp, directory);
    const actual = JSON.parse(readFileSync(join(directory, "mcp.json"), "utf8"));
    expect(actual.mcpServers.exa.env).toEqual({
      EXA_API_KEY: key === "${EXA_API_KEY}" ? command : key,
      HTTPS_PROXY: "http://127.0.0.1:2080",
      NODE_USE_ENV_PROXY: "1",
    });
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});
