import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { realpathSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join, relative, resolve } from "node:path";
import { Type } from "typebox";
import { Check } from "typebox/value";

const searchInput = Type.Object({ path: Type.Optional(Type.String()) });
const searchTools = new Set(["find", "grep", "fffind", "ffgrep", "multi_grep", "fff-multi-grep"]);
const storePackage = /^[0-9abcdfghijklmnpqrsvwxyz]{32}-[^/]+$/;

function indexRoot(path: string, cwd: string): string {
  if (path === "~" || path.startsWith("~/")) path = join(homedir(), path.slice(1));
  const parts = resolve(cwd, path).split("/");
  const glob = parts.findIndex((part) => /[*?[{]/.test(part));
  if (glob !== -1) parts.splice(glob);

  // FFF indexes the deepest existing non-glob directory, not the result filter.
  for (let root = parts.join("/") || "/"; ; root = dirname(root)) {
    try {
      return realpathSync(statSync(root).isFile() ? dirname(root) : root);
    } catch (error) {
      if (root === dirname(root)) throw error;
    }
  }
}

export function isBroadNixStoreSearch(path: string, cwd: string, store = "/nix/store"): boolean {
  const root = indexRoot(path, cwd);
  if (root === store || store.startsWith(root.replace(/\/$/, "") + "/")) return true;
  if (!root.startsWith(store + "/")) return false;
  return !storePackage.test(relative(store, root).split("/")[0]);
}

export default function fffNixStoreGuard(pi: Pick<ExtensionAPI, "on">) {
  pi.on("tool_call", (event, ctx) => {
    if (!searchTools.has(event.toolName)) return;
    if (!Check(searchInput, event.input)) throw new Error("Search path must be a string");
    if (!isBroadNixStoreSearch(event.input.path?.trim() || ".", ctx.cwd)) return;
    return {
      block: true,
      reason: "Blocked broad FFF search of /nix/store: it creates a recursive index and filesystem watches; pattern, exclude and limit do not bound that work. "
        + "Avoid searching the store when possible: use Nix metadata or pkg-config to locate the dependency. "
        + "Otherwise select one existing /nix/store/<hash>-<package> path (no glob in the package component), then retry within it. "
        + "To discover package paths without indexing, use bash: printf '%s\\n' /nix/store/*-ffmpeg-*. "
        + "For content, use bash with a filtered, one-shot ripgrep command, e.g. rg -n -g '*.h' -- 'avcodec_open2' /nix/store/<hash>-ffmpeg-dev/include. "
        + "Do not replace this with an unfiltered recursive scan of the whole store.",
    };
  });
}
