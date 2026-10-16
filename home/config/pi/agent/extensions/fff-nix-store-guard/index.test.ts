import { afterEach, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, realpathSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { join, relative } from "node:path";
import type { ExtensionContext, ExtensionHandler, ToolCallEvent, ToolCallEventResult } from "@earendil-works/pi-coding-agent";
import extension, { isBroadNixStoreSearch } from "./index";

type Handler = ExtensionHandler<ToolCallEvent, ToolCallEventResult>;
interface SearchInput {
  path?: string;
  pattern?: string;
  limit?: number;
  exclude?: string;
  command?: string;
}
const fixtures: string[] = [];
afterEach(() => fixtures.splice(0).forEach((path) => rmSync(path, { recursive: true, force: true })));

function fixture() {
  const base = realpathSync(mkdtempSync(join(tmpdir(), "fff-store-guard-")));
  fixtures.push(base);
  const store = join(base, "nix/store");
  const cwd = join(base, "workspace");
  const pkg = join(store, "0123456789abcdfghijklmnpqrsvwxyz-ffmpeg-dev");
  mkdirSync(join(pkg, "include"), { recursive: true });
  mkdirSync(join(store, ".links"));
  mkdirSync(join(store, "ffmpeg"));
  mkdirSync(cwd);
  writeFileSync(join(pkg, "include/avcodec.h"), "header");
  writeFileSync(join(store, "package-file"), "not a package directory");
  symlinkSync(store, join(cwd, "store-link"));
  symlinkSync(pkg, join(cwd, "package-link"));
  return { base, store, cwd, pkg, blocked: (path: string, directory = cwd) => isBroadNixStoreSearch(path, directory, store) };
}

test("blocks the whole store, ancestor roots, package globs and missing package fallbacks", () => {
  const f = fixture();
  for (const path of [
    f.store, `${f.store}/`, `${f.store}/../store`, `${f.store}/**/*.h`,
    `${f.store}/*ffmpeg*/include`, `${f.store}/{ffmpeg,openssl}/include`,
    `${f.store}/ffmpeg/include`, `${f.store}/.links`, `${f.store}/package-file`,
    `${f.pkg}-missing/include`, `${f.base}/nix`, `${f.base}/nix/*/include`,
  ]) {
    expect(f.blocked(path), path).toBe(true);
  }
});

test("allows existing concrete packages, their files, leaf globs and missing children", () => {
  const f = fixture();
  for (const path of [f.pkg, `${f.pkg}/include`, `${f.pkg}/include/avcodec.h`, `${f.pkg}/**/*.h`, `${f.pkg}/missing/file.h`]) {
    expect(f.blocked(path), path).toBe(false);
  }
});

test("resolves relative, home-relative and symlink paths before applying the boundary", () => {
  const f = fixture();
  expect(f.blocked(relative(f.cwd, f.store))).toBe(true);
  expect(f.blocked("store-link/*ffmpeg*/include")).toBe(true);
  expect(f.blocked(`~/${relative(homedir(), f.store)}`)).toBe(true);
  expect(f.blocked(".", f.store)).toBe(true);
  expect(f.blocked("package-link/include")).toBe(false);
  expect(f.blocked(".", f.pkg)).toBe(false);
});

test("leaves ordinary workspace searches and similarly named directories alone", () => {
  const f = fixture();
  mkdirSync(`${f.store}-backup`);
  for (const path of [".", "*.ts", "src/", `${f.store}-backup`]) {
    expect(f.blocked(path), path).toBe(false);
  }
});

function guard(cwd: string) {
  let handler: Handler | undefined;
  extension({
    on<E, R>(name: string, callback: ExtensionHandler<E, R>) {
      expect(name).toBe("tool_call");
      // SAFETY: This extension registers only tool_call; the fixture dispatches that exact event.
      handler = callback as Handler;
      return () => { handler = undefined; };
    },
  });
  return (toolName: string, input: SearchInput, parentToolCallId?: string) => {
    if (!handler) throw new Error("Missing tool_call handler");
    // SAFETY: The guard only reads cwd and needs no UI or session APIs.
    const context = { cwd } as ExtensionContext;
    return handler({ type: "tool_call", toolCallId: "search", toolName, input, parentToolCallId }, context);
  };
}

test.each(["find", "grep", "fffind", "ffgrep", "multi_grep", "fff-multi-grep"])("blocks %s before execution, including nested codemode calls", async (tool) => {
  const check = guard(fixture().cwd);
  const result = await check(tool, { path: " /nix/store/ ", pattern: "ffmpeg", limit: 1, exclude: "**" }, "codemode/search");
  expect(result?.block).toBe(true);
  expect(result?.reason).toContain("filesystem watches");
  expect(result?.reason).toContain("pkg-config");
  expect(result?.reason).toContain("rg -n -g '*.h'");
  expect(result?.reason).toContain("/nix/store/<hash>-<package>");
});

test("does not interpret search text as an external index request or block non-search tools", async () => {
  const check = guard(fixture().cwd);
  expect(await check("find", { pattern: "/nix/store" })).toBeUndefined();
  expect(await check("grep", { path: "*.ts", pattern: "/nix/store" })).toBeUndefined();
  expect(await check("read", { path: "/nix/store" })).toBeUndefined();
  expect(await check("bash", { command: "printf '%s\\n' /nix/store/*-ffmpeg-*" })).toBeUndefined();
});

test("checks the workspace root when path is absent or empty", async () => {
  const check = guard("/nix/store");
  expect((await check("fffind", { pattern: "ffmpeg" }))?.block).toBe(true);
  expect((await check("ffgrep", { path: "  ", pattern: "avcodec" }))?.block).toBe(true);
});
