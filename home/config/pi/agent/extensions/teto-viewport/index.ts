import { mkdir, rename, rm, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { getCellDimensions, visibleWidth, type TUI } from "@earendil-works/pi-tui";
import { detect, type Ledge } from "./detect.ts";

type MainScreen = {
	previousLines: string[];
	previousViewportTop: number;
};

type ScrollBox = {
	children: ScrollBox[];
	rect: { x: number; y: number; width: number; height: number };
	scrollView?: { scrollTop: number };
	scrollContentLines?: string[];
};

type Fullscreen = {
	getScreenLines(): string[];
	currentLayout?: { root: ScrollBox; primaryScrollView?: ScrollBox["scrollView"] };
};

function isMainScreen(value: TUI): value is TUI & MainScreen {
	return value.mode === "regular" && "previousLines" in value && Array.isArray(value.previousLines) &&
		"previousViewportTop" in value && typeof value.previousViewportTop === "number";
}

function isFullscreen(value: TUI): value is TUI & Fullscreen {
	return value.mode === "fullscreen" && "getScreenLines" in value && typeof value.getScreenLines === "function";
}

function findScrollBox(box: ScrollBox, view: ScrollBox["scrollView"]): ScrollBox | undefined {
	if (view && box.scrollView === view) return box;
	for (const child of box.children) {
		const found = findScrollBox(child, view);
		if (found) return found;
	}
}

function fullscreenLedges(tui: TUI & Fullscreen, cols: number, rows: number, background: string): Ledge[] {
	const layout = tui.currentLayout;
	const box = layout && findScrollBox(layout.root, layout.primaryScrollView);
	const screen = detect(tui.getScreenLines(), 0, cols, rows, background, visibleWidth);
	if (!box?.scrollContentLines || !box.scrollView) return screen;

	const { x, y, width, height } = box.rect;
	const top = box.scrollView.scrollTop;
	const chat = detect(box.scrollContentLines, top, box.children[0]?.rect.width ?? width, height, background, visibleWidth);
	return [...screen.filter((ledge) => ledge.row < y || ledge.row >= y + height),
		...chat.map((ledge) => ({ ...ledge, id: `chat:${ledge.id}`, row: y + ledge.row, x1: x + ledge.x1, x2: x + ledge.x2 }))];
}

export default function (pi: ExtensionAPI) {
	const id = process.env.HC_TERMINAL_ID;
	if (!id || !/^t[a-z0-9]+$/.test(id) || process.env.SSH_CONNECTION) return;
	const directory = join(homedir(), ".cache", "teto98");
	const path = join(directory, `pi-${id}.json`);
	const temporary = `${path}.${process.pid}.tmp`;
	let pending: string | undefined;
	let last = "";
	let writing: Promise<void> | undefined;
	let stopped = false;
	let started = false;

	function publish(value: string) {
		if (value === last || stopped) return;
		last = value;
		pending = value;
		if (writing) return;
		writing = (async () => {
			while (pending !== undefined) {
				const data = pending;
				pending = undefined;
				await writeFile(temporary, data, { mode: 0o600 });
				await rename(temporary, path);
			}
		})().catch(() => {
			// A cache write failure must not paint over the TUI.
			last = "";
		}).finally(() => { writing = undefined; });
	}

	pi.on("session_start", async (_event, ctx) => {
		if (!ctx.hasUI) return;
		await mkdir(directory, { recursive: true });
		started = true;
		ctx.ui.setWidget("teto-viewport", (tui, theme) => {
			let scheduled = false;
			function publishViewport() {
				scheduled = false;
				if (stopped || (!isMainScreen(tui) && !isFullscreen(tui))) return;
				const cols = tui.terminal.columns;
				const rows = tui.terminal.rows;
				if (cols <= 0 || rows <= 0) return;

				const background = /^\x1b\[[0-9;]*m/.exec(theme.bg("userMessageBg", " "))?.[0] ?? "";
				const dimensions = getCellDimensions();
				// Pi defaults to 9x18 before receiving a measurement; do not report that guess.
				const cell = dimensions.widthPx === 9 && dimensions.heightPx === 18 ? undefined : { width: dimensions.widthPx, height: dimensions.heightPx };
				const ledges = tui.hasOverlay() ? [] : isMainScreen(tui)
					? detect(tui.previousLines, tui.previousViewportTop, cols, rows, background, visibleWidth)
					: fullscreenLedges(tui, cols, rows, background);
				publish(JSON.stringify({ version: 1, cols, rows, cell, ledges }));
			}
			return {
				render() {
					// Pi commits the viewport after rendering components.
					if (!stopped && !scheduled) {
						scheduled = true;
						queueMicrotask(publishViewport);
					}
					return [];
				},
				invalidate() {},
				dispose() { stopped = true; },
			};
		});
	});
	pi.on("session_shutdown", async () => {
		if (!started) return;
		stopped = true;
		await writing;
		await rm(path, { force: true });
		await rm(temporary, { force: true });
	});
}
