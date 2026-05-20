import type {
	ExtensionAPI,
	ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { Text, truncateToWidth } from "@earendil-works/pi-tui";
import { existsSync, readFileSync, unlinkSync, writeFileSync } from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

interface ChangeRecord {
	path: string;
	absolutePath: string;
	status: "created" | "modified" | "discarded" | "resolved";
	tools: string[];
	firstChangedAt: number;
	lastChangedAt: number;
	beforeExists: boolean;
	beforeContent?: string;
	afterExists: boolean;
	diff?: string;
	firstChangedLine?: number;
}

interface Snapshot {
	path: string;
	absolutePath: string;
	exists: boolean;
	content?: string;
}

interface FileChangesState {
	changes: ChangeRecord[];
}

const CUSTOM_TYPE = "file-changes";
const WIDGET_ID = "file-changes";
const TRACKED_TOOLS = new Set(["write", "edit"]);

function stripAtPrefix(filePath: string): string {
	return filePath.startsWith("@") ? filePath.slice(1) : filePath;
}

function resolvePath(filePath: string, cwd: string): string {
	const clean = stripAtPrefix(filePath);
	if (clean.startsWith("~/"))
		return path.join(process.env.HOME ?? "", clean.slice(2));
	return path.isAbsolute(clean) ? clean : path.resolve(cwd, clean);
}

function relativePath(absolutePath: string, cwd: string): string {
	const rel = path.relative(cwd, absolutePath);
	return rel && !rel.startsWith("..") && !path.isAbsolute(rel)
		? rel
		: absolutePath;
}

function readSnapshot(rawPath: string, ctx: ExtensionContext): Snapshot {
	const absolutePath = resolvePath(rawPath, ctx.cwd);
	try {
		return {
			path: relativePath(absolutePath, ctx.cwd),
			absolutePath,
			exists: true,
			content: readFileSync(absolutePath, "utf8"),
		};
	} catch {
		return {
			path: relativePath(absolutePath, ctx.cwd),
			absolutePath,
			exists: false,
		};
	}
}

function firstChangedLine(before: string, after: string): number | undefined {
	const a = before.split("\n");
	const b = after.split("\n");
	const max = Math.max(a.length, b.length);
	for (let i = 0; i < max; i++) {
		if (a[i] !== b[i]) return i + 1;
	}
	return undefined;
}

function makeDiff(filePath: string, before: string, after: string): string {
	if (before === after) return "";
	const beforeLines = before.split("\n");
	const afterLines = after.split("\n");
	const changed = firstChangedLine(before, after) ?? 1;
	const start = Math.max(1, changed - 3);
	let beforeEnd = beforeLines.length;
	let afterEnd = afterLines.length;
	while (
		beforeEnd >= start &&
		afterEnd >= start &&
		beforeLines[beforeEnd - 1] === afterLines[afterEnd - 1]
	) {
		beforeEnd--;
		afterEnd--;
	}
	beforeEnd = Math.min(beforeLines.length, beforeEnd + 3);
	afterEnd = Math.min(afterLines.length, afterEnd + 3);

	const lines = [
		`--- a/${filePath}`,
		`+++ b/${filePath}`,
		`@@ -${start},${Math.max(0, beforeEnd - start + 1)} +${start},${Math.max(0, afterEnd - start + 1)} @@`,
	];
	for (let i = start - 1; i < beforeEnd; i++)
		lines.push(`-${beforeLines[i] ?? ""}`);
	for (let i = start - 1; i < afterEnd; i++)
		lines.push(`+${afterLines[i] ?? ""}`);
	return lines.join("\n");
}

function stateFromBranch(ctx: ExtensionContext): FileChangesState {
	let state: FileChangesState = { changes: [] };
	for (const entry of ctx.sessionManager.getBranch()) {
		if (entry.type !== "custom" || entry.customType !== CUSTOM_TYPE) continue;
		const data = entry.data as FileChangesState | undefined;
		if (data?.changes) state = { changes: data.changes };
	}
	return state;
}

function changeIcon(status: ChangeRecord["status"]): string {
	if (status === "created") return "A";
	if (status === "discarded") return "↩";
	if (status === "resolved") return "✓";
	return "M";
}

function activeChanges(state: FileChangesState): ChangeRecord[] {
	return state.changes.filter(
		(c) => c.status !== "discarded" && c.status !== "resolved",
	);
}

function updateWidget(ctx: ExtensionContext, state: FileChangesState): void {
	const active = activeChanges(state);
	if (active.length === 0) {
		ctx.ui.setWidget(WIDGET_ID, undefined);
		ctx.ui.setStatus(WIDGET_ID, undefined);
		return;
	}

	ctx.ui.setStatus(WIDGET_ID, ctx.ui.theme.fg("accent", `Δ ${active.length}`));
	ctx.ui.setWidget(WIDGET_ID, (_tui, theme) => {
		const lines = [
			theme.fg(
				"accent",
				`Δ ${active.length} changed file${active.length === 1 ? "" : "s"}`,
			),
		];
		for (const change of active.slice(0, 8)) {
			const color = change.status === "created" ? "success" : "warning";
			lines.push(
				`${theme.fg(color, changeIcon(change.status))} ${theme.fg("muted", change.path)}`,
			);
		}
		if (active.length > 8)
			lines.push(theme.fg("dim", `… ${active.length - 8} more`));
		lines.push(
			theme.fg("dim", "/changes to inspect, open, discard, or mark resolved"),
		);
		return new Text(lines.join("\n"), 0, 0);
	});
}

function shellWords(command: string): string[] {
	return (
		command
			.match(/(?:[^\s"']+|"[^"]*"|'[^']*')+/g)
			?.map((part) => part.replace(/^(["'])(.*)\1$/, "$2")) ?? []
	);
}

function openInNvim(change: ChangeRecord, ctx: ExtensionContext): void {
	const editorCommand = process.env.PI_NVIM_CMD || process.env.NVIM || "nvim";
	const [cmd, ...cmdArgs] = shellWords(editorCommand);
	if (!cmd) {
		ctx.ui.notify("PI_NVIM_CMD is empty", "error");
		return;
	}

	const wasRaw = Boolean(process.stdin.isTTY && process.stdin.isRaw);
	try {
		if (process.stdin.isTTY) process.stdin.setRawMode(false);
		process.stdout.write("\x1b[2J\x1b[H");
		const lineArg = change.firstChangedLine
			? `+${change.firstChangedLine}`
			: undefined;
		const args = [
			...cmdArgs,
			...(lineArg ? [lineArg] : []),
			change.absolutePath,
		];
		const result = spawnSync(cmd, args, {
			cwd: ctx.cwd,
			stdio: "inherit",
			shell: process.platform === "win32",
		});
		if (result.error)
			ctx.ui.notify(
				`Failed to launch Neovim: ${result.error.message}`,
				"error",
			);
		else if (result.status !== 0)
			ctx.ui.notify(`Neovim exited with status ${result.status}`, "warning");
	} finally {
		if (process.stdin.isTTY) process.stdin.setRawMode(wasRaw);
	}
}

async function showDiff(
	change: ChangeRecord,
	ctx: ExtensionContext,
): Promise<void> {
	await ctx.ui.custom<void>((_tui, theme, _kb, done) => ({
		render(width: number) {
			const title = theme.fg("accent", `Diff: ${change.path}`);
			const diff = change.diff || "No diff available";
			return [
				title,
				"",
				...diff.split("\n").map((line) => truncateToWidth(line, width)),
				"",
				theme.fg("dim", "Press Escape to close"),
			];
		},
		invalidate() {},
		handleInput(data: string) {
			if (data === "\u001b" || data === "\u0003") done();
		},
	}));
}

async function discardChange(
	change: ChangeRecord,
	ctx: ExtensionContext,
): Promise<boolean> {
	if (!change.beforeExists) {
		const ok = await ctx.ui.confirm(
			"Discard created file?",
			`Delete ${change.path}?`,
		);
		if (!ok) return false;
		try {
			if (existsSync(change.absolutePath)) unlinkSync(change.absolutePath);
			return true;
		} catch (error) {
			ctx.ui.notify(
				`Failed to delete ${change.path}: ${error instanceof Error ? error.message : String(error)}`,
				"error",
			);
			return false;
		}
	}

	try {
		writeFileSync(change.absolutePath, change.beforeContent ?? "", "utf8");
		return true;
	} catch (error) {
		ctx.ui.notify(
			`Failed to restore ${change.path}: ${error instanceof Error ? error.message : String(error)}`,
			"error",
		);
		return false;
	}
}

export default function fileChanges(pi: ExtensionAPI): void {
	let state: FileChangesState = { changes: [] };
	const snapshots = new Map<string, Snapshot>();

	function persist(ctx: ExtensionContext): void {
		pi.appendEntry(CUSTOM_TYPE, state);
		updateWidget(ctx, state);
	}

	function upsertChange(
		toolName: string,
		before: Snapshot,
		after: Snapshot,
		toolDiff?: string,
		firstLine?: number,
	): void {
		if (before.exists && after.exists && before.content === after.content)
			return;

		const existing = state.changes.find(
			(c) => c.absolutePath === before.absolutePath && c.status !== "discarded",
		);
		const beforeContent = existing?.beforeContent ?? before.content;
		const beforeExists = existing?.beforeExists ?? before.exists;
		const afterContent = after.content ?? "";
		const baseline = beforeExists ? (beforeContent ?? "") : "";
		const status: ChangeRecord["status"] = beforeExists
			? "modified"
			: "created";
		const now = Date.now();
		const diff = toolDiff || makeDiff(before.path, baseline, afterContent);
		const record: ChangeRecord = {
			path: before.path,
			absolutePath: before.absolutePath,
			status,
			tools: Array.from(new Set([...(existing?.tools ?? []), toolName])),
			firstChangedAt: existing?.firstChangedAt ?? now,
			lastChangedAt: now,
			beforeExists,
			beforeContent,
			afterExists: after.exists,
			diff,
			firstChangedLine:
				firstLine ??
				existing?.firstChangedLine ??
				firstChangedLine(baseline, afterContent),
		};

		if (existing) Object.assign(existing, record);
		else state.changes.push(record);
	}

	pi.on("session_start", async (_event, ctx) => {
		state = stateFromBranch(ctx);
		updateWidget(ctx, state);
	});

	pi.on("session_tree", async (_event, ctx) => {
		state = stateFromBranch(ctx);
		updateWidget(ctx, state);
	});

	pi.on("tool_call", async (event, ctx) => {
		if (!TRACKED_TOOLS.has(event.toolName)) return;
		const input = event.input as { path?: unknown };
		const rawPath = typeof input.path === "string" ? input.path : undefined;
		if (!rawPath) return;
		snapshots.set(event.toolCallId, readSnapshot(rawPath, ctx));
	});

	pi.on("tool_result", async (event, ctx) => {
		if (!TRACKED_TOOLS.has(event.toolName) || event.isError) return;
		const before = snapshots.get(event.toolCallId);
		snapshots.delete(event.toolCallId);
		const rawPath =
			typeof event.input.path === "string" ? event.input.path : before?.path;
		if (!before || !rawPath) return;
		const after = readSnapshot(rawPath, ctx);
		const editDetails =
			event.toolName === "edit"
				? (event.details as
						| { diff?: string; firstChangedLine?: number }
						| undefined)
				: undefined;
		upsertChange(
			event.toolName,
			before,
			after,
			editDetails?.diff,
			editDetails?.firstChangedLine,
		);
		persist(ctx);
	});

	pi.on("before_agent_start", async () => {
		const active = activeChanges(state);
		if (active.length === 0) return;
		return {
			message: {
				customType: "file-changes-context",
				content: `Currently tracked changed files:\n${active.map((c) => `${changeIcon(c.status)} ${c.path}`).join("\n")}`,
				display: false,
			},
		};
	});

	pi.registerCommand("changes", {
		description:
			"Inspect tracked file changes, open them in Neovim, discard them, or mark them resolved",
		handler: async (_args, ctx) => {
			state = stateFromBranch(ctx);
			const active = activeChanges(state);
			if (active.length === 0) {
				ctx.ui.notify("No tracked file changes", "info");
				updateWidget(ctx, state);
				return;
			}

			const labels = active.map(
				(c, i) => `${i + 1}. ${changeIcon(c.status)} ${c.path}`,
			);
			const picked = await ctx.ui.select("Changed files", labels);
			if (!picked) return;
			const change = active[labels.indexOf(picked)];
			if (!change) return;

			const action = await ctx.ui.select(change.path, [
				"Open in Neovim",
				"View diff",
				"Discard change",
				"Mark resolved",
			]);
			if (action === "Open in Neovim") openInNvim(change, ctx);
			else if (action === "View diff") await showDiff(change, ctx);
			else if (action === "Discard change") {
				if (await discardChange(change, ctx)) {
					change.status = "discarded";
					change.lastChangedAt = Date.now();
					persist(ctx);
					ctx.ui.notify(`Discarded ${change.path}`, "info");
				}
			} else if (action === "Mark resolved") {
				change.status = "resolved";
				change.lastChangedAt = Date.now();
				persist(ctx);
			}
		},
	});

	pi.registerCommand("changes-clear", {
		description: "Clear resolved or discarded file changes from the tracker",
		handler: async (_args, ctx) => {
			state = {
				changes: stateFromBranch(ctx).changes.filter(
					(c) => c.status !== "discarded" && c.status !== "resolved",
				),
			};
			persist(ctx);
			ctx.ui.notify("Cleared resolved/discarded file changes", "info");
		},
	});

	pi.registerCommand("changes-open", {
		description: "Open a tracked changed file in Neovim",
		handler: async (args, ctx) => {
			state = stateFromBranch(ctx);
			const active = activeChanges(state);
			const change = args.trim()
				? active.find((c) => c.path.includes(args.trim()))
				: active.length === 1
					? active[0]
					: undefined;
			if (!change) {
				ctx.ui.notify("Run /changes to select a changed file", "info");
				return;
			}
			openInNvim(change, ctx);
		},
	});

	pi.registerCommand("changes-discard", {
		description:
			"Discard a tracked changed file by path substring, or use /changes for a picker",
		handler: async (args, ctx) => {
			state = stateFromBranch(ctx);
			const needle = args.trim();
			const matches = activeChanges(state).filter((c) =>
				needle ? c.path.includes(needle) : true,
			);
			const change = matches.length === 1 ? matches[0] : undefined;
			if (!change) {
				ctx.ui.notify("Run /changes to select a changed file", "info");
				return;
			}
			if (await discardChange(change, ctx)) {
				change.status = "discarded";
				change.lastChangedAt = Date.now();
				persist(ctx);
				ctx.ui.notify(`Discarded ${change.path}`, "info");
			}
		},
	});
}
