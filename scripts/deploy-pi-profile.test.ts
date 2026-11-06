import { expect, test } from "bun:test";
import { $ } from "bun";
import { mkdirSync, mkdtempSync, readFileSync, readlinkSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { exportProfile } from "./deploy-pi-profile";
import { syncProfile } from "../modules/paseo/pi-profile.mjs";
import { installProfile, profileIsCurrent } from "../modules/paseo/install-profile";

const root = resolve(import.meta.dir, "..");

test("the work profile uses the private Exa file without proxying Pi or Exa", async () => {
  const shared = await exportProfile(undefined, root);
  const instructions = (await $`tar -xOf - ./pi/AGENTS.md < ${shared.archive}`.quiet()).stdout.toString();
  expect(instructions).toBe(readFileSync(join(root, "home/config/agents/AGENTS.md"), "utf8"));
  const work = await exportProfile(undefined, root, "work");
  const desktop = await exportProfile(undefined, root, "desktop");
  const sharedSettings = JSON.parse((await $`tar -xOf - ./pi/settings.json < ${shared.archive}`.quiet()).stdout.toString());
  const workSettings = JSON.parse((await $`tar -xOf - ./pi/settings.json < ${work.archive}`.quiet()).stdout.toString());

  expect(sharedSettings.httpProxy).toBeUndefined();
  expect(workSettings).toEqual(sharedSettings);
  expect(work.metadata.contentDigest).not.toBe(shared.metadata.contentDigest);
  expect(desktop.metadata.contentDigest).toBe(shared.metadata.contentDigest);

  const sharedMcp = JSON.parse((await $`tar -xOf - ./pi/mcp.json < ${shared.archive}`.quiet()).stdout.toString());
  const workMcp = JSON.parse((await $`tar -xOf - ./pi/mcp.json < ${work.archive}`.quiet()).stdout.toString());
  expect(sharedMcp.mcpServers.exa.env.EXA_API_KEY).toBe("${EXA_API_KEY}");
  expect(workMcp.mcpServers.exa.env).toEqual({
    ...sharedMcp.mcpServers.exa.env,
    EXA_API_KEY: '!. "$HOME/.config/pi/exa.env" && printf %s "$EXA_API_KEY"',
  });
  const entries = (await $`tar -tf - < ${work.archive}`.quiet()).stdout.toString();
  expect(entries).not.toContain("exa.env");
  expect(entries).not.toContain("shared/secrets");
  for (const name of ["sgconfig.yml", "svelte-parser.json", "zig-parser.json", "README.md", "tests/", "rules/common/", "rules/frg/"]) {
    expect(entries).toContain(`./ast-grep/${name}`);
  }
  const sharedConfig = Bun.YAML.parse((await $`tar -xOf - ./ast-grep/sgconfig.yml < ${shared.archive}`.quiet()).stdout.toString());
  const workConfig = Bun.YAML.parse((await $`tar -xOf - ./ast-grep/sgconfig.yml < ${work.archive}`.quiet()).stdout.toString());
  expect(sharedConfig.ruleDirs).toEqual(["rules/common"]);
  expect(workConfig).toEqual({ ...sharedConfig, ruleDirs: ["rules"] });
});

test.each(["work", "desktop"])("deployment scopes rules and scans Svelte and Zig on %s", async (host) => {
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
    expect(readlinkSync(join(home, ".pi/agent/AGENTS.md"))).toBe(join(release, "pi/AGENTS.md"));
    expect(readFileSync(join(home, ".pi/agent/AGENTS.md"), "utf8"))
      .toBe(readFileSync(join(root, "home/config/agents/AGENTS.md"), "utf8"));
    expect(readlinkSync(join(home, ".config/ast-grep"))).toBe(join(release, "ast-grep"));
    expect(readlinkSync(join(home, "develop/frg/sgconfig.yml"))).toBe(join(release, "sgconfig-frg.yml"));

    const project = join(home, "projects/example");
    mkdirSync(project, { recursive: true });
    writeFileSync(join(project, "Plain.svelte"), '<script>const result = ready ? Reflect.get(value, "key") : null;</script>');
    writeFileSync(join(project, "Typed.svelte"), '<script lang="ts">const result = ready ? Reflect.get(value, "key") : null;</script>');
    writeFileSync(join(project, "plain.ts"), 'const result = ready ? Reflect.get(value, "key") : null;');
    writeFileSync(join(project, "ownership.zig"), `
const a = try std.json.parseFromSliceLeaky(T, std.testing.allocator, input, .{});
const b = try std.json.parseFromTokenSourceLeaky(T, std.heap.page_allocator, &reader, .{});
const c = try std.json.parseFromValueLeaky(T, std.heap.c_allocator, value, .{});
const d = (try std.json.parseFromSlice(T, arena_allocator, input, .{})).value;
const e = (try std.json.parseFromTokenSource(T, arena.allocator(), &reader, .{})).value;
const f = (try std.json.parseFromValue(T, self.request_arena.allocator(), value, .{})).value;
`);
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
    for (const file of ["Plain.svelte", "Typed.svelte", "plain.ts", "ownership.zig"]) {
      writeFileSync(join(frgProject, file), readFileSync(join(project, file)));
    }
    const frgScan = await $`ast-grep scan --json`.cwd(frgProject).quiet().nothrow();
    expect(frgScan.exitCode).toBe(1);
    const frgFindings: { ruleId: string; file: string }[] = JSON.parse(frgScan.stdout.toString());
    for (const [file, language] of [["Plain.svelte", "javascript"], ["Typed.svelte", "typescript"], ["plain.ts", "typescript"]]) {
      expect(frgFindings.filter(finding => finding.file.endsWith(file)).map(finding => finding.ruleId))
        .toContain(`no-ternary-in-${language}`);
    }
    for (const scanFindings of [findings, frgFindings]) {
      const zigRules = scanFindings.filter(finding => finding.file.endsWith("ownership.zig")).map(finding => finding.ruleId);
      for (const source of ["slice", "token-source", "value"]) {
        expect(zigRules).toContain(`no-json-parse-from-${source}-leaky-with-general-allocator-zig`);
        expect(zigRules).toContain(`prefer-json-parse-from-${source}-leaky-for-arena-value-zig`);
      }
      expect(zigRules).toHaveLength(6);
    }
    // The shared suite has valid/invalid cases for all rules, but only eight snapshot baselines.
    await $`ast-grep test --skip-snapshot-tests --config ${join(home, "sgconfig.yml")}`.cwd(project).quiet();
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
}, 120_000);

test("syncs model and thinking defaults over host-local settings", async () => {
  const home = mkdtempSync(join(tmpdir(), "pi-model-sync-"));
  try {
    const directory = join(home, ".pi/agent");
    mkdirSync(directory, { recursive: true });
    const mcp = join(home, "mcp.json");
    writeFileSync(mcp, JSON.stringify({ mcpServers: {} }));
    writeFileSync(join(directory, "settings.json"), JSON.stringify({
      defaultProvider: "fumo", defaultModel: "codex/gpt-6.1-sol", defaultThinkingLevel: "low", theme: "light",
    }));

    await syncProfile(join(root, "home/config/pi/agent/settings.json"), mcp, directory, undefined, home);
    const actual = JSON.parse(readFileSync(join(directory, "settings.json"), "utf8"));
    expect(actual.defaultProvider).toBe("fumo");
    expect(actual.defaultModel).toBe("codex/gpt-6.1-terra");
    expect(actual.defaultThinkingLevel).toBe("high");
    expect(actual.theme).toBe("light");
  } finally {
    rmSync(home, { recursive: true, force: true });
  }
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
