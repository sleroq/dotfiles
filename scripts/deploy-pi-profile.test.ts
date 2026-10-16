import { expect, test } from "bun:test";
import { $ } from "bun";
import { mkdirSync, mkdtempSync, readFileSync, readlinkSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { exportProfile } from "./deploy-pi-profile";
import { syncProfile } from "../modules/paseo/pi-profile.mjs";
import { installProfile, profileIsCurrent } from "../modules/paseo/install-profile";

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
  for (const name of ["sgconfig.yml", "svelte-parser.json", "README.md", "tests/", "rules/common/", "rules/frg/"]) {
    expect(entries).toContain(`./ast-grep/${name}`);
  }
  const sharedConfig = Bun.YAML.parse((await $`tar -xOf - ./ast-grep/sgconfig.yml < ${shared.archive}`.quiet()).stdout.toString());
  const workConfig = Bun.YAML.parse((await $`tar -xOf - ./ast-grep/sgconfig.yml < ${work.archive}`.quiet()).stdout.toString());
  expect(sharedConfig.ruleDirs).toEqual(["rules/common"]);
  expect(workConfig).toEqual({ ...sharedConfig, ruleDirs: ["rules"] });
});

test.each(["work", "desktop"])("deployment scopes rules and scans Svelte on %s", async (host) => {
  const directory = mkdtempSync(join(tmpdir(), "pi ast-grep deployment "));
  try {
    const home = join(directory, "home");
    const release = join(directory, "release");
    mkdirSync(release);
    mkdirSync(join(home, "develop/frg"), { recursive: true });
    symlinkSync("/old/sgconfig-frg.yml", join(home, "develop/frg/sgconfig.yml"));
    const bundle = await exportProfile(undefined, root, host);
    await $`tar -xf - -C ${release} < ${bundle.archive}`.quiet();
    await installProfile(bundle.metadata, true, release, home);
    expect(profileIsCurrent(bundle.metadata, true, home)).toBe(true);
    expect(readlinkSync(join(home, ".config/ast-grep"))).toBe(join(release, "ast-grep"));
    expect(readlinkSync(join(home, "develop/frg/sgconfig.yml"))).toBe(join(release, "sgconfig-frg.yml"));

    const project = join(home, "projects/example");
    mkdirSync(project, { recursive: true });
    writeFileSync(join(project, "Plain.svelte"), '<script>const result = ready ? Reflect.get(value, "key") : null;</script>');
    writeFileSync(join(project, "Typed.svelte"), '<script lang="ts">const result = ready ? Reflect.get(value, "key") : null;</script>');
    writeFileSync(join(project, "plain.ts"), 'const result = ready ? Reflect.get(value, "key") : null;');
    // Exercise ancestor config discovery, not just an explicitly supplied config.
    const scan = await $`ast-grep scan --json`.cwd(project).quiet().nothrow();
    let expectedExit = 0;
    if (host === "work") {
      expectedExit = 1; // The FRG ternary rule has error severity.
    }
    expect(scan.exitCode).toBe(expectedExit);
    const findings: { ruleId: string; file: string }[] = JSON.parse(scan.stdout.toString());
    for (const [file, language] of [["Plain.svelte", "javascript"], ["Typed.svelte", "typescript"], ["plain.ts", "typescript"]]) {
      const rules = findings.filter(finding => finding.file.endsWith(file)).map(finding => finding.ruleId);
      if (host === "work") {
        expect(rules).toContain(`no-ternary-in-${language}`);
      } else {
        expect(rules).not.toContain(`no-ternary-in-${language}`);
      }
    }
    for (const file of ["Typed.svelte", "plain.ts"]) {
      expect(findings.filter(finding => finding.file.endsWith(file)).map(finding => finding.ruleId))
        .toContain("no-reflect-get-typescript");
    }
    const frgProject = join(home, "develop/frg/example");
    mkdirSync(frgProject);
    for (const file of ["Plain.svelte", "Typed.svelte", "plain.ts"]) {
      writeFileSync(join(frgProject, file), readFileSync(join(project, file)));
    }
    const frgScan = await $`ast-grep scan --json`.cwd(frgProject).quiet().nothrow();
    expect(frgScan.exitCode).toBe(1);
    const frgFindings: { ruleId: string; file: string }[] = JSON.parse(frgScan.stdout.toString());
    for (const [file, language] of [["Plain.svelte", "javascript"], ["Typed.svelte", "typescript"], ["plain.ts", "typescript"]]) {
      expect(frgFindings.filter(finding => finding.file.endsWith(file)).map(finding => finding.ruleId))
        .toContain(`no-ternary-in-${language}`);
    }
    // The shared suite has valid/invalid cases for all rules, but only eight snapshot baselines.
    await $`ast-grep test --skip-snapshot-tests --config ${join(home, "sgconfig.yml")}`.cwd(project).quiet();
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
}, 120_000);

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
