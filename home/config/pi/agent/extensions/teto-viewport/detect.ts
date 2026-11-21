export type Ledge = { id: string; row: number; x1: number; x2: number; kind: "message" | "rule" | "image" };

type Width = (text: string) => number;
const ansi = /\x1b\[[0-?]*[ -/]*[@-~]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)/g;

export function detect(lines: string[], top: number, cols: number, rows: number, background: string, width: Width): Ledge[] {
	const ledges: Ledge[] = [];
	function message(line: string) { return background !== "" && line.includes(background) && width(line) >= cols; }
	function add(kind: Ledge["kind"], index: number, x1: number, x2: number) {
		if (index < top || index >= top + rows || x1 >= cols || x2 <= x1) return;
		ledges.push({ id: `${kind}:${index}:${x1}`, row: index - top, x1, x2: Math.min(cols, x2), kind });
	}
	for (let i = top; i < Math.min(lines.length, top + rows); i++) {
		const line = lines[i];
		if (message(line) && (i === 0 || !message(lines[i - 1]))) add("message", i, 0, cols);

		const kitty = line.indexOf("\x1b_G");
		if (kitty >= 0) {
			const headerEnd = line.indexOf(";", kitty);
			if (headerEnd >= 0) {
				const header = line.slice(kitty + 3, headerEnd);
				const columns = /(?:^|,)c=(\d+)(?:,|$)/.exec(header);
				if (columns) {
					const x = width(line.slice(0, kitty));
					add("image", i, x, x + Number(columns[1]));
				}
			}
			continue;
		}
		const iterm = line.indexOf("\x1b]1337;File=");
		if (iterm >= 0) {
			const before = line.slice(0, iterm);
			const up = /\x1b\[(\d+)A$/.exec(before);
			const headerEnd = line.indexOf(":", iterm);
			const columns = /[;=]width=(\d+)(?:;|$)/.exec(line.slice(iterm, headerEnd));
			if (columns) {
				const x = width(up ? before.slice(0, up.index) : before);
				add("image", i - Number(up?.[1] ?? 0), x, x + Number(columns[1]));
			}
			continue;
		}
		const plain = line.replace(ansi, "");
		for (const match of plain.matchAll(/[─━╌╍┄┅┈┉═]{4,}|-{8,}/gu)) {
			const x = width(plain.slice(0, match.index));
			add("rule", i, x, x + width(match[0]));
		}
	}
	return ledges;
}
