import { $ } from "bun";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

interface ParserSource {
  owner: string;
  repo: string;
  rev: string;
}

async function buildParser(directory: string, language: "svelte" | "zig", env: NodeJS.ProcessEnv) {
  const source: ParserSource = JSON.parse(readFileSync(join(directory, `${language}-parser.json`), "utf8"));
  const staging = mkdtempSync(join(tmpdir(), `ast-grep-${language}-`));
  const parsers = join(directory, "parsers");
  mkdirSync(parsers, { recursive: true });
  try {
    const archive = join(staging, "source.tar.gz");
    await $`curl --fail --location --silent --show-error https://codeload.github.com/${source.owner}/${source.repo}/tar.gz/${source.rev} -o ${archive}`.env(env);
    await $`tar -xzf ${archive} --strip-components=1 -C ${staging}`.env(env);
    if (language === "svelte") {
      // The scanner's tree-sitter Array macros require -fno-strict-aliasing.
      await $`cc -O2 -shared -fPIC -fno-strict-aliasing -Isrc src/parser.c src/scanner.c -o ${join(parsers, "tree-sitter-svelte")}`
        .cwd(join(staging, "crates/tree-sitter-svelte")).env(env);
    } else {
      await $`cc -O2 -shared -fPIC -Isrc src/parser.c -o ${join(parsers, "tree-sitter-zig")}`.cwd(staging).env(env);
    }
  } finally {
    rmSync(staging, { recursive: true, force: true });
  }
}

export async function installAstGrep(release: string, env: NodeJS.ProcessEnv) {
  const directory = join(release, "ast-grep");
  await buildParser(directory, "svelte", env);
  await buildParser(directory, "zig", env);
  const config = readFileSync(join(directory, "sgconfig.yml"), "utf8")
    .replace("  - rules/common\n", `  - ${JSON.stringify(join(directory, "rules/common"))}\n`)
    .replace("  - rules\n", `  - ${JSON.stringify(join(directory, "rules"))}\n`)
    .replace("parsers/tree-sitter-svelte", JSON.stringify(join(directory, "parsers/tree-sitter-svelte")))
    .replace("parsers/tree-sitter-zig", JSON.stringify(join(directory, "parsers/tree-sitter-zig")))
    .replace("testDir: tests", `testDir: ${JSON.stringify(join(directory, "tests"))}`);
  const path = join(release, "sgconfig.yml");
  writeFileSync(path, config);
  const commonRules = `  - ${JSON.stringify(join(directory, "rules/common"))}\n`;
  writeFileSync(join(release, "sgconfig-frg.yml"), config.replace(
    commonRules, `${commonRules}  - ${JSON.stringify(join(directory, "rules/frg"))}\n`,
  ));
  // Newer ast-grep requires explicit consent before loading native parsers.
  const help = await $`ast-grep --help`.env(env).quiet();
  const customLanguages = help.stdout.toString().includes("--custom-languages") ? ["--custom-languages", "allow"] : [];
  // Load both custom parsers and compile the shared patterns before activation.
  await $`ast-grep ${customLanguages} run --config ${path} --lang svelte --pattern '<script>$CONTENT</script>' --stdin < ${Buffer.from('<script>const value = 1;</script>')}`.env(env).quiet();
  await $`ast-grep ${customLanguages} run --config ${path} --lang svelte --pattern '<script lang="ts">$CONTENT</script>' --stdin < ${Buffer.from('<script lang="ts">const value: number = 1;</script>')}`.env(env).quiet();
  await $`ast-grep ${customLanguages} run --config ${path} --lang zig --pattern 'std.json.parseFromSliceLeaky($T, $ALLOC, $INPUT, $OPTIONS)' --stdin < ${Buffer.from('const value = try std.json.parseFromSliceLeaky(T, arena_allocator, input, .{});')}`.env(env).quiet();
}
