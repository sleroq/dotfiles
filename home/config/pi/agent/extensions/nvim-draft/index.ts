import { randomBytes } from "node:crypto";
import { once } from "node:events";
import { existsSync, lstatSync, mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { createServer } from "node:net";
import { homedir } from "node:os";
import { isAbsolute, join, relative, sep } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isKeyRelease, type TUI } from "@earendil-works/pi-tui";

const focusIn = "\x1b[I";
const focusOut = "\x1b[O";
const widget = "nvim-draft";

function selectionReference(request: string, cwd: string): string | undefined {
	const selection: unknown = JSON.parse(request);
	if (!selection || typeof selection !== "object" || !("path" in selection) || !("first" in selection) || !("last" in selection)) return;
	const { path, first, last } = selection;
	if (typeof path !== "string" || !isAbsolute(path) || /[\x00-\x1f\x7f]/.test(path)) return;
	if (typeof first !== "number" || typeof last !== "number" || !Number.isSafeInteger(first) || !Number.isSafeInteger(last) || first < 1 || last < first) return;

	const local = relative(cwd, path);
	const file = local && !isAbsolute(local) && local !== ".." && !local.startsWith(".." + sep) ? local : path;
	return first === last ? `${file}:${first}` : `${file}:${first}-${last}`;
}

export default function (pi: ExtensionAPI) {
	let stop: (() => void) | undefined;

	pi.on("session_start", async (_event, ctx) => {
		if (ctx.mode !== "tui" || !process.stdin.isTTY || !process.stdout.isTTY || process.platform === "win32") return;
		const directory = join(process.env.XDG_STATE_HOME || join(homedir(), ".local", "state"), "pi-draft");
		mkdirSync(directory, { recursive: true, mode: 0o700 });
		const stat = lstatSync(directory);
		if (!stat.isDirectory() || stat.uid !== process.getuid?.() || (stat.mode & 0o077) !== 0) {
			ctx.ui.notify("Pi draft bridge needs a private state directory: " + directory, "warning");
			return;
		}

		const id = randomBytes(6).toString("hex");
		const last = join(directory, "last");
		const temporary = join(directory, id + ".tmp");
		let tui: TUI | undefined;
		const server = createServer((socket) => {
			let request = "";
			socket.setEncoding("utf8").setTimeout(1000, () => socket.destroy());
			socket.on("error", () => socket.destroy());
			socket.on("data", (chunk: string) => {
				request += chunk;
				if (request.length > 8192) return socket.destroy();
				const end = request.indexOf("\n");
				if (end < 0) return;

				socket.pause();
				let reference: string | undefined;
				try { reference = selectionReference(request.slice(0, end), ctx.cwd); } catch { /* Invalid JSON. */ }
				if (!reference) return socket.end("Invalid file or line range\n");

				const draft = ctx.ui.getEditorText();
				ctx.ui.setEditorText(draft + (draft && !draft.endsWith("\n") ? "\n" : "") + reference);
				tui?.requestRender();
				socket.end("ok\n");
			});
		});
		server.listen(join(directory, id + ".sock"));
		await once(server, "listening");
		server.unref();

		function markActive() {
			try {
				if (existsSync(last) && readFileSync(last, "utf8") === id) return;
				writeFileSync(temporary, id, { mode: 0o600 });
				renameSync(temporary, last);
			} catch {
				// Losing the state directory must not interrupt terminal input.
			}
		}

		// Fullscreen Pi consumes focus and mouse reports before extension input handlers.
		function onPointerInput(data: string) {
			for (const [, button] of data.matchAll(/\x1b\[<(\d+);\d+;\d+M/g)) {
				if ((Number(button) & 32) === 0) { markActive(); break; }
			}
			if (data.includes(focusIn)) markActive();
		}
		process.stdin.on("data", onPointerInput);

		const unsubscribe = ctx.ui.onTerminalInput(data => {
			if (data === focusIn || data === focusOut) return { consume: true };
			// Ignore key-up events and terminal capability/size replies, not typing or navigation.
			if (!isKeyRelease(data) && !/^(?:\x1b\[(?:[?>=]|[0-9;]+[ntcR]$)|\x1b\])/.test(data)) markActive();
		});
		ctx.ui.setWidget(widget, (ui) => {
			tui = ui;
			let mode: TUI["mode"] | undefined;
			return {
				render() {
					if (ui.mode !== mode && ui.mode === "regular") ui.terminal.write("\x1b[?1004h");
					mode = ui.mode;
					return [];
				},
				invalidate() {},
			};
		});
		stop = () => {
			if (tui?.mode === "regular") tui.terminal.write("\x1b[?1004l");
			process.stdin.off("data", onPointerInput);
			unsubscribe();
			server.close();
		};
	});
	pi.on("session_shutdown", () => stop?.());
}
