import { expect, test } from "bun:test";
import { detect } from "./detect.ts";

const bg = "\x1b[48;2;1;2;3m";
function width(text: string) { return [...text.replace(/\x1b\[[0-?]*[ -/]*[@-~]/g, "")].length; }

test("message tops use absolute indices and never restart at a clipped continuation", () => {
	const lines = ["heading", `${bg}          \x1b[0m`, `${bg} user     \x1b[0m`, "", `${bg}          \x1b[0m`];
	expect(detect(lines, 1, 10, 4, bg, width)).toEqual([
		{ id: "message:1:0", row: 0, x1: 0, x2: 10, kind: "message" },
		{ id: "message:4:0", row: 3, x1: 0, x2: 10, kind: "message" },
	]);
	expect(detect(lines, 2, 10, 3, bg, width)).toEqual([
		{ id: "message:4:0", row: 2, x1: 0, x2: 10, kind: "message" },
	]);
});

test("detects long rules and image cell widths without including payloads", () => {
	const lines = ["  ────────────────", "xx --- text", "  \x1b_Ga=T,c=6,r=3;secret\x1b\\", " \x1b[2A\x1b]1337;File=width=4;inline=1:secret\x07"];
	expect(detect(lines, 0, 20, 4, bg, width)).toEqual([
		{ id: "rule:0:2", row: 0, x1: 2, x2: 18, kind: "rule" },
		{ id: "image:2:2", row: 2, x1: 2, x2: 8, kind: "image" },
		{ id: "image:1:1", row: 1, x1: 1, x2: 5, kind: "image" },
	]);
});
