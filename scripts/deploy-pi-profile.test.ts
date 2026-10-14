import { expect, test } from "bun:test";
import { $ } from "bun";
import { resolve } from "node:path";
import { exportProfile } from "./deploy-pi-profile";

const root = resolve(import.meta.dir, "..");

test("only the work profile uses the local HTTP proxy", async () => {
  const shared = await exportProfile(undefined, root);
  const work = await exportProfile(undefined, root, "work");
  const desktop = await exportProfile(undefined, root, "desktop");
  const sharedSettings = JSON.parse((await $`tar -xOf - ./pi/settings.json < ${shared.archive}`.quiet()).stdout.toString());
  const workSettings = JSON.parse((await $`tar -xOf - ./pi/settings.json < ${work.archive}`.quiet()).stdout.toString());

  expect(sharedSettings.httpProxy).toBeUndefined();
  expect(workSettings).toEqual({ ...sharedSettings, httpProxy: "http://127.0.0.1:2080" });
  expect(work.metadata.contentDigest).not.toBe(shared.metadata.contentDigest);
  expect(desktop.metadata.contentDigest).toBe(shared.metadata.contentDigest);
});
