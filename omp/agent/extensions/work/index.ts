import * as fs from "node:fs";
import * as path from "node:path";
import type { AgentRegistry, ExtensionAPI, ExtensionContext } from "@oh-my-pi/pi-coding-agent";

type RegistryEvent = Parameters<Parameters<ReturnType<typeof AgentRegistry.global>["onChange"]>[0]>[0];

// Open-loop tracker: persistent per-project work state (running / blocked /
// decisions / next / cleanup) plus a live view of task subagents, exposed as a
// `work` tool for the model, a `/work` command for the user, and a widget.

const SECTIONS = ["running", "blocked", "decisions", "next", "cleanup"] as const;
type Section = (typeof SECTIONS)[number];

type Item = { id: number; text: string; at: number };
type AgentStatus = "running" | "idle" | "done" | "failed" | "aborted";
type AgentRow = {
	toolCallId: string;
	index: number;
	agent: string;
	name?: string;
	task: string;
	status: AgentStatus;
	summary?: string;
	startedAt: number;
	endedAt?: number;
	/** Async job id when the spawn was detached (async.enabled). */
	jobId?: string;
	/** Registry id of the subagent, once known. */
	agentId?: string;
};
type State = Record<Section, Item[]> & { seq: number; agents: AgentRow[] };

const STATE_FILE = path.join(".omp", "work.json");
const FINISHED_TTL_MS = 30 * 60 * 1000;
const WIDGET_KEY = "work";

function emptyState(): State {
	return { seq: 0, running: [], blocked: [], decisions: [], next: [], cleanup: [], agents: [] };
}

function statePath(cwd: string): string {
	return path.join(cwd, STATE_FILE);
}

function load(cwd: string): State {
	try {
		const raw = JSON.parse(fs.readFileSync(statePath(cwd), "utf8")) as Partial<State>;
		const state = emptyState();
		state.seq = typeof raw.seq === "number" ? raw.seq : 0;
		for (const s of SECTIONS) if (Array.isArray(raw[s])) state[s] = raw[s] as Item[];
		// Rows still "running" belong to a previous process and cannot be tracked.
		state.agents = (Array.isArray(raw.agents) ? raw.agents : []).map((a) =>
			a.status === "running" ? { ...a, status: "aborted" as const, endedAt: a.endedAt ?? Date.now() } : a,
		);
		return state;
	} catch {
		return emptyState();
	}
}

function save(cwd: string, state: State): boolean {
	try {
		const file = statePath(cwd);
		fs.mkdirSync(path.dirname(file), { recursive: true });
		const tmp = `${file}.tmp`;
		fs.writeFileSync(tmp, JSON.stringify(state, null, 2));
		fs.renameSync(tmp, file);
		return true;
	} catch {
		return false;
	}
}

function isEmpty(state: State): boolean {
	return SECTIONS.every((s) => state[s].length === 0) && state.agents.length === 0;
}

function firstLine(text: string, max = 100): string {
	const line = text.split("\n").find((l) => l.trim().length > 0)?.trim() ?? "";
	return line.length > max ? `${line.slice(0, max - 1)}…` : line;
}

function pruneFinished(state: State): void {
	const cutoff = Date.now() - FINISHED_TTL_MS;
	state.agents = state.agents.filter((a) => a.status === "running" || a.status === "idle" || (a.endedAt ?? 0) > cutoff);
}

function agentLabel(a: AgentRow): string {
	return a.name ? `${a.agent}:${a.name}` : a.agent;
}

function render(state: State): string {
	const lines: string[] = [];
	for (const s of SECTIONS) {
		if (state[s].length === 0) continue;
		lines.push(s[0].toUpperCase() + s.slice(1));
		for (const item of state[s]) lines.push(`  ${item.id}. ${item.text}`);
	}
	if (state.agents.length > 0) {
		lines.push("Agents");
		for (const a of state.agents) {
			const mark = a.status === "running" ? "●" : a.status === "done" ? "✓" : a.status === "idle" ? "◌" : "✗";
			const tail = a.summary ? `: ${a.summary}` : "";
			lines.push(`  ${mark} ${agentLabel(a)} [${a.status}] ${firstLine(a.task, 60)}${tail}`);
		}
	}
	return lines.length > 0 ? lines.join("\n") : "No open work.";
}

export default function work(pi: ExtensionAPI): void {
	const z = pi.zod;
	let state: State = emptyState();
	let loadedFor: string | undefined;
	let unsubscribeRegistry: (() => void) | undefined;

	function ensureLoaded(ctx: ExtensionContext): void {
		if (loadedFor === ctx.cwd) return;
		state = load(ctx.cwd);
		loadedFor = ctx.cwd;
	}

	function persist(ctx: ExtensionContext): void {
		if (!save(ctx.cwd, state)) pi.appendEntry("work", state);
	}

	function refresh(ctx: ExtensionContext): void {
		if (!ctx.hasUI) return;
		pruneFinished(state);
		if (isEmpty(state)) {
			ctx.ui.setWidget(WIDGET_KEY, undefined);
			return;
		}
		const t = ctx.ui.theme;
		const running = state.agents.filter((a) => a.status === "running" || a.status === "idle");
		const finished = state.agents.length - running.length;
		const parts: string[] = [];
		if (running.length > 0) {
			const names = running
				.slice(0, 3)
				.map((a) => `${agentLabel(a)}: ${firstLine(a.task, 28)}`)
				.join(", ");
			const more = running.length > 3 ? ` +${running.length - 3}` : "";
			parts.push(t.fg("accent", `agents ${running.length} running`) + t.fg("dim", ` (${names}${more})`));
		}
		if (finished > 0) parts.push(t.fg("success", `${finished} done`));
		if (state.blocked.length > 0) parts.push(t.fg("warning", `blocked ${state.blocked.length}`));
		if (state.decisions.length > 0) parts.push(t.fg("error", `decisions ${state.decisions.length}`));
		if (state.running.length > 0) parts.push(t.fg("muted", `running ${state.running.length}`));
		const lines = [t.fg("muted", "work  ") + parts.join(t.fg("dim", " · "))];
		const next = state.next[0];
		if (next) lines.push(t.fg("dim", "      next: ") + firstLine(next.text, 80));
		ctx.ui.setWidget(WIDGET_KEY, lines, { placement: "aboveEditor" });
	}

	function commit(ctx: ExtensionContext): void {
		persist(ctx);
		refresh(ctx);
	}

	function findItem(id: number): { section: Section; index: number } | undefined {
		for (const s of SECTIONS) {
			const index = state[s].findIndex((i) => i.id === id);
			if (index !== -1) return { section: s, index };
		}
		return undefined;
	}

	function addItem(section: Section, text: string): Item {
		const item = { id: ++state.seq, text: text.trim(), at: Date.now() };
		state[section].push(item);
		return item;
	}

	function removeItem(id: number): Item | undefined {
		const found = findItem(id);
		if (!found) return undefined;
		return state[found.section].splice(found.index, 1)[0];
	}

	function moveItem(id: number, to: Section): Item | undefined {
		const item = removeItem(id);
		if (!item) return undefined;
		state[to].push(item);
		return item;
	}

	// ---- task subagent tracking ------------------------------------------------

	type TaskArgs = { agent?: string; task?: string; name?: string; tasks?: TaskArgs[] };
	type TaskResult = { index?: number; agent?: string; task?: string; exitCode?: number; output?: string };
	type TaskDetails = { results?: TaskResult[]; async?: { state: "running" | "completed" | "failed"; jobId?: string } };

	function isLive(a: AgentRow): boolean {
		return a.status === "running" || a.status === "idle";
	}

	function normalizeTaskArgs(args: unknown): TaskArgs[] {
		const a = (args ?? {}) as TaskArgs;
		return Array.isArray(a.tasks) ? a.tasks : [a];
	}

	function onTaskStart(toolCallId: string, args: unknown): void {
		normalizeTaskArgs(args).forEach((t, index) => {
			state.agents.push({
				toolCallId,
				index,
				agent: t.agent ?? "task",
				name: t.name,
				task: t.task ?? "",
				status: "running",
				startedAt: Date.now(),
			});
		});
	}

	function onTaskEnd(toolCallId: string, result: unknown, isError: boolean, ctx: ExtensionContext): void {
		const rows = state.agents.filter((a) => a.toolCallId === toolCallId);
		if (rows.length === 0) return;
		const details = (result as { details?: TaskDetails } | undefined)?.details;
		if (details?.async?.state === "running") {
			// Detached spawn: the tool call returns immediately. The job snapshot and
			// the agent registry finish these rows later (see reconcileJobs).
			for (const row of rows) row.jobId = details.async.jobId;
			return;
		}
		const now = Date.now();
		const results = details?.results ?? [];
		for (const row of rows) {
			const r = results.find((x) => x.index === row.index) ?? results[row.index];
			if (r) {
				row.status = r.exitCode === 0 ? "done" : "failed";
				row.summary = firstLine(r.output ?? "");
			} else if (isError || results.length > 0) {
				row.status = "failed";
			} else {
				row.status = "done";
			}
			row.endedAt = now;
			if (ctx.hasUI) ctx.ui.notify(`${agentLabel(row)} ${row.status}${row.summary ? `: ${row.summary}` : ""}`, row.status === "failed" ? "warning" : "info");
		}
	}

	function reconcileJobs(ctx: ExtensionContext): boolean {
		const pending = state.agents.filter((a) => a.jobId && isLive(a));
		if (pending.length === 0) return false;
		const snapshot = ctx.getAsyncJobSnapshot();
		if (!snapshot) return false;
		let changed = false;
		for (const row of pending) {
			const live = snapshot.running.find((j) => j.id === row.jobId);
			if (live) {
				if (live.agentId && row.agentId !== live.agentId) {
					row.agentId = live.agentId;
					changed = true;
				}
				continue;
			}
			const finished = snapshot.recent.find((j) => j.id === row.jobId);
			if (!finished) continue;
			row.status = finished.status === "completed" ? "done" : finished.status === "cancelled" ? "aborted" : "failed";
			row.endedAt = Date.now();
			changed = true;
		}
		return changed;
	}

	function onRegistryEvent(event: RegistryEvent, ctx: ExtensionContext): void {
		const ref = event.ref;
		if (ref.kind !== "sub") return;
		const row =
			state.agents.find((a) => isLive(a) && a.agentId === ref.id) ??
			state.agents.find((a) => isLive(a) && a.name !== undefined && (a.name === ref.displayName || ref.displayName.endsWith(`:${a.name}`)));
		if (!row) return;
		row.agentId = ref.id;
		if (event.type === "removed") {
			// A removed detached job resolves through the snapshot; treat others as aborted.
			if (!row.jobId) {
				row.status = "aborted";
				row.endedAt = Date.now();
			}
		} else if (ref.status === "idle" || ref.status === "parked") {
			row.status = "idle";
		} else if (ref.status === "aborted") {
			row.status = "aborted";
			row.endedAt = Date.now();
		} else if (ref.status === "running") {
			row.status = "running";
		}
		refresh(ctx);
	}

	// ---- tool -------------------------------------------------------------------

	const SectionSchema = z.enum(SECTIONS);
	type WorkParams = {
		op: "add" | "done" | "drop" | "move" | "list" | "clear";
		section?: Section;
		text?: string;
		id?: number;
		to?: Section;
	};
	pi.registerTool({
		name: "work",
		label: "Work",
		description:
			"Open-loop tracker for multi-step work. Sections: running (in-flight things you own), blocked (and what unblocks them), decisions (need user input), next (ordered next actions), cleanup (leftovers to remove). ops: add {section,text}; done {id}; drop {id}; move {id,to}; list; clear. Keep it current as work progresses; call list before a handoff.",
		parameters: z.object({
			op: z.enum(["add", "done", "drop", "move", "list", "clear"]),
			section: SectionSchema.optional().describe("for add"),
			text: z.string().optional().describe("for add"),
			id: z.number().int().optional().describe("for done/drop/move"),
			to: SectionSchema.optional().describe("for move"),
		}),
		approval: "read",
		loadMode: "essential",
		async execute(_toolCallId, rawParams, _signal, _onUpdate, ctx) {
			const params = rawParams as WorkParams;
			ensureLoaded(ctx);
			let note = "";
			switch (params.op) {
				case "add": {
					if (!params.section || !params.text) return fail("add needs section and text");
					const item = addItem(params.section, params.text);
					note = `added #${item.id} to ${params.section}`;
					break;
				}
				case "done":
				case "drop": {
					if (params.id === undefined) return fail(`${params.op} needs id`);
					const item = removeItem(params.id);
					if (!item) return fail(`no item #${params.id}`);
					note = `${params.op === "done" ? "completed" : "dropped"} #${item.id}: ${item.text}`;
					break;
				}
				case "move": {
					if (params.id === undefined || !params.to) return fail("move needs id and to");
					const item = moveItem(params.id, params.to);
					if (!item) return fail(`no item #${params.id}`);
					note = `moved #${item.id} to ${params.to}`;
					break;
				}
				case "clear":
					state = { ...emptyState(), seq: state.seq };
					note = "cleared";
					break;
				case "list":
					break;
			}
			if (params.op !== "list") commit(ctx);
			const body = render(state);
			return { content: [{ type: "text", text: note ? `${note}\n\n${body}` : body }], details: state };
		},
	});

	function fail(message: string) {
		return { content: [{ type: "text" as const, text: message }], isError: true };
	}

	// ---- command ----------------------------------------------------------------

	const SUBCOMMANDS = ["add", "done", "drop", "move", "clear", "agents"];
	pi.registerCommand("work", {
		description: "Show or edit open work: /work [add <section> <text> | done <id> | drop <id> | move <id> <section> | clear | agents]",
		getArgumentCompletions: (prefix) => {
			const items = SUBCOMMANDS.filter((s) => s.startsWith(prefix)).map((s) => ({ value: s, label: s }));
			return items.length > 0 ? items : null;
		},
		handler: async (args, ctx) => {
			ensureLoaded(ctx);
			const [sub, ...rest] = args.trim().split(/\s+/).filter(Boolean);
			const notify = (msg: string, type: "info" | "warning" | "error" = "info") => ctx.ui.notify(msg, type);
			if (reconcileJobs(ctx)) persist(ctx);
			if (!sub) return notify(render(state));
			switch (sub) {
				case "add": {
					const [section, ...words] = rest;
					if (!SECTIONS.includes(section as Section) || words.length === 0)
						return notify(`usage: /work add <${SECTIONS.join("|")}> <text>`, "warning");
					const item = addItem(section as Section, words.join(" "));
					commit(ctx);
					return notify(`added #${item.id} to ${section}`);
				}
				case "done":
				case "drop": {
					const id = Number(rest[0]);
					const item = Number.isInteger(id) ? removeItem(id) : undefined;
					if (!item) return notify(`usage: /work ${sub} <id>`, "warning");
					commit(ctx);
					return notify(`${sub === "done" ? "completed" : "dropped"} #${item.id}: ${item.text}`);
				}
				case "move": {
					const id = Number(rest[0]);
					const to = rest[1] as Section;
					const item = Number.isInteger(id) && SECTIONS.includes(to) ? moveItem(id, to) : undefined;
					if (!item) return notify(`usage: /work move <id> <${SECTIONS.join("|")}>`, "warning");
					commit(ctx);
					return notify(`moved #${item.id} to ${to}`);
				}
				case "clear":
					state = { ...emptyState(), seq: state.seq };
					commit(ctx);
					return notify("work cleared");
				case "agents": {
					if (state.agents.length === 0) return notify("No tracked agents.");
					const lines = state.agents.map((a) => {
						const dur = Math.round(((a.endedAt ?? Date.now()) - a.startedAt) / 1000);
						return `${agentLabel(a)} [${a.status}, ${dur}s] ${firstLine(a.task, 80)}${a.summary ? `\n    ${a.summary}` : ""}`;
					});
					return notify(lines.join("\n"));
				}
				default:
					return notify(`unknown subcommand '${sub}'. ${SUBCOMMANDS.join(" | ")}`, "warning");
			}
		},
	});

	// ---- lifecycle --------------------------------------------------------------

	pi.on("session_start", (_event, ctx) => {
		loadedFor = undefined;
		ensureLoaded(ctx);
		unsubscribeRegistry?.();
		unsubscribeRegistry = pi.pi.AgentRegistry.global().onChange((event) => onRegistryEvent(event, ctx));
		refresh(ctx);
	});

	pi.on("tool_execution_start", (event, ctx) => {
		if (event.toolName !== "task") return;
		ensureLoaded(ctx);
		onTaskStart(event.toolCallId, event.args);
		commit(ctx);
	});

	pi.on("tool_execution_end", (event, ctx) => {
		if (event.toolName !== "task") return;
		ensureLoaded(ctx);
		onTaskEnd(event.toolCallId, event.result, event.isError, ctx);
		commit(ctx);
	});

	pi.on("turn_end", (_event, ctx) => {
		ensureLoaded(ctx);
		if (reconcileJobs(ctx)) persist(ctx);
		refresh(ctx);
	});

	pi.on("session_shutdown", (_event, ctx) => {
		unsubscribeRegistry?.();
		unsubscribeRegistry = undefined;
		if (ctx.hasUI) ctx.ui.setWidget(WIDGET_KEY, undefined);
	});
}
