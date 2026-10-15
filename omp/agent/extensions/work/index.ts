import * as fs from "node:fs";
import * as path from "node:path";
import { setTimeout as delay } from "node:timers/promises";
import type { AgentRegistry, ExtensionAPI, ExtensionContext } from "@oh-my-pi/pi-coding-agent";

type RegistryEvent = Parameters<Parameters<ReturnType<typeof AgentRegistry.global>["onChange"]>[0]>[0];

// Open-loop tracker: persistent per-project work state (running / blocked /
// decisions / next / cleanup) plus a live view of task subagents, exposed as a
// `work` tool for the model, a `/work` command for the user, and a widget.

const SECTIONS = ["running", "blocked", "decisions", "next", "cleanup"] as const;
type Section = (typeof SECTIONS)[number];

type Item = { id: number; text: string; at: number };
type AgentStatus = "running" | "idle" | "parked" | "done" | "failed" | "aborted";
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
	let raw: unknown;
	try {
		raw = JSON.parse(fs.readFileSync(statePath(cwd), "utf8"));
	} catch (error) {
		if (error instanceof Error && "code" in error && error.code === "ENOENT") return emptyState();
		throw new Error(`Cannot read work ledger; refusing to overwrite it: ${String(error)}`);
	}
	if (typeof raw !== "object" || raw === null || Array.isArray(raw)) throw new Error("Invalid work ledger; expected an object.");
	const state = emptyState();
	if ("seq" in raw) {
		if (typeof raw.seq !== "number" || !Number.isSafeInteger(raw.seq) || raw.seq < 0) throw new Error("Invalid work ledger sequence.");
		state.seq = raw.seq;
	}
	for (const section of SECTIONS) {
		if (!(section in raw)) continue;
		const items: unknown = Reflect.get(raw, section);
		if (!Array.isArray(items)) throw new Error(`Invalid work ledger section: ${section}`);
		for (const item of items) {
			if (typeof item !== "object" || item === null
				|| !("id" in item) || typeof item.id !== "number" || !Number.isSafeInteger(item.id) || item.id < 1
				|| !("text" in item) || typeof item.text !== "string"
				|| !("at" in item) || typeof item.at !== "number" || !Number.isFinite(item.at)) {
				throw new Error(`Invalid work ledger item in ${section}; refusing to discard it.`);
			}
			state[section].push({ id: item.id, text: item.text, at: item.at });
			state.seq = Math.max(state.seq, item.id);
		}
	}
	// Registry/job state belongs to this session, never a previous process.
	return state;
}

function save(cwd: string, state: State): void {
	const file = statePath(cwd);
	const tmp = `${file}.${process.pid}.${crypto.randomUUID()}.tmp`;
	try {
		fs.writeFileSync(tmp, JSON.stringify({ ...state, agents: [] }, null, 2));
		fs.renameSync(tmp, file);
	} finally {
		fs.rmSync(tmp, { force: true });
	}
}

function isEmpty(state: State): boolean {
	return SECTIONS.every((s) => state[s].length === 0) && state.agents.length === 0;
}

function firstLine(text: string, max = 100): string {
	const line = text.split("\n").find((l) => l.trim().length > 0)?.trim() ?? "";
	return line.length > max ? `${line.slice(0, max - 1)}…` : line;
}

function pruneFinished(state: State): boolean {
	const cutoff = Date.now() - FINISHED_TTL_MS;
	const previousLength = state.agents.length;
	state.agents = state.agents.filter((a) => isLive(a) || (a.endedAt ?? 0) > cutoff);
	return state.agents.length !== previousLength;
}

function isLive(a: AgentRow): boolean {
	return a.status === "running" || a.status === "idle" || a.status === "parked";
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
			const mark = a.status === "running" ? "●" : a.status === "done" ? "✓" : a.status === "idle" || a.status === "parked" ? "◌" : "✗";
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
	const sessionAgents = new Map<string, AgentRow[]>();
	let unsubscribeRegistry: (() => void) | undefined;

	function ensureLoaded(ctx: ExtensionContext): void {
		const next = load(ctx.cwd);
		const key = `${ctx.cwd}\0${ctx.sessionManager.getSessionId()}`;
		if (loadedFor !== undefined) sessionAgents.set(loadedFor, state.agents);
		next.agents = sessionAgents.get(key) ?? [];
		state = next;
		loadedFor = key;
	}

	async function editLedger<T>(ctx: ExtensionContext, edit: () => T): Promise<T> {
		const file = statePath(ctx.cwd);
		const lock = `${file}.lock`;
		fs.mkdirSync(path.dirname(file), { recursive: true });
		const deadline = Date.now() + 2000;
		let fd: number;
		while (true) {
			try {
				fd = fs.openSync(lock, "wx");
				break;
			} catch (error) {
				if (!(error instanceof Error && "code" in error && error.code === "EEXIST")) throw error;
				if (Date.now() >= deadline) throw new Error(`Work ledger is locked: ${lock}. Retry after the other writer finishes; if it crashed, remove this lock only after confirming no writer is active.`);
				await delay(25);
			}
		}
		try {
			fs.writeFileSync(fd, `${process.pid}\n`);
			ensureLoaded(ctx);
			// No await between loading, applying the edit, and saving under the lock.
			return edit();
		} finally {
			fs.closeSync(fd);
			fs.unlinkSync(lock);
		}
	}

	function refresh(ctx: ExtensionContext): void {
		if (!ctx.hasUI) return;
		if (isEmpty(state)) {
			ctx.ui.setWidget(WIDGET_KEY, undefined);
			return;
		}
		const t = ctx.ui.theme;
		const running = state.agents.filter((a) => a.status === "running");
		const parts: string[] = [];
		if (running.length > 0) {
			const names = running
				.slice(0, 3)
				.map((a) => `${agentLabel(a)}: ${firstLine(a.task, 28)}`)
				.join(", ");
			const more = running.length > 3 ? ` +${running.length - 3}` : "";
			parts.push(t.fg("accent", `agents ${running.length} running`) + t.fg("dim", ` (${names}${more})`));
		}
		for (const status of ["idle", "parked", "done", "failed", "aborted"] as const) {
			const count = state.agents.filter((a) => a.status === status).length;
			if (count > 0) parts.push(t.fg(status === "done" ? "success" : status === "failed" || status === "aborted" ? "warning" : "dim", `${count} ${status}`));
		}
		if (state.blocked.length > 0) parts.push(t.fg("warning", `blocked ${state.blocked.length}`));
		if (state.decisions.length > 0) parts.push(t.fg("error", `decisions ${state.decisions.length}`));
		if (state.running.length > 0) parts.push(t.fg("muted", `running ${state.running.length}`));
		if (state.next.length > 0) parts.push(t.fg("dim", `next ${state.next.length}`));
		if (state.cleanup.length > 0) parts.push(t.fg("dim", `cleanup ${state.cleanup.length}`));
		const lines = [t.fg("muted", "work  ") + parts.join(t.fg("dim", " · "))];
		const next = state.next[0];
		if (next) lines.push(t.fg("dim", "      next: ") + firstLine(next.text, 80));
		ctx.ui.setWidget(WIDGET_KEY, lines, { placement: "aboveEditor" });
	}

	function commit(ctx: ExtensionContext): void {
		pruneFinished(state);
		save(ctx.cwd, state);
		refresh(ctx);
	}

	function synchronize(ctx: ExtensionContext): void {
		ensureLoaded(ctx);
		reconcileJobs(ctx);
		reconcileAgents(ctx);
		pruneFinished(state);
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

	function reconcileJobs(ctx: ExtensionContext): void {
		const pending = state.agents.filter((a) => a.jobId && isLive(a));
		if (pending.length === 0) return;
		const snapshot = ctx.getAsyncJobSnapshot();
		if (!snapshot) return;
		for (const row of pending) {
			const live = snapshot.running.find((j) => j.id === row.jobId);
			if (live) {
				if (live.agentId) row.agentId = live.agentId;
				continue;
			}
			const finished = snapshot.recent.find((j) => j.id === row.jobId);
			if (!finished) continue;
			row.status = finished.status === "completed" ? "done" : finished.status === "cancelled" ? "aborted" : "failed";
			row.endedAt = Date.now();
		}
	}

	function reconcileAgents(ctx: ExtensionContext): void {
		const registry = pi.pi.AgentRegistry.global();
		const refs = registry.list().filter((ref) => ref.kind === "sub");
		const snapshot = ctx.getAsyncJobSnapshot();
		for (const row of state.agents) {
			const ref = row.agentId ? registry.get(row.agentId) : refs.find((candidate) =>
				row.name !== undefined && (candidate.displayName === row.name || candidate.displayName.endsWith(`:${row.name}`))
				&& candidate.createdAt >= row.startedAt - 1000);
			if (ref) {
				row.agentId = ref.id;
				if (!isLive(row) && !(ref.status === "running" && ref.lastActivity > (row.endedAt ?? Infinity))) continue;
				if (!isLive(row)) row.jobId = undefined;
				row.status = ref.status;
				row.endedAt = ref.status === "aborted" ? Date.now() : undefined;
			} else if (isLive(row) && row.agentId && !(row.jobId && snapshot?.running.some((job) => job.id === row.jobId))) {
				row.status = "aborted";
				row.endedAt = Date.now();
			}
		}
	}

	function onRegistryEvent(event: RegistryEvent, ctx: ExtensionContext): void {
		if (event.ref.kind !== "sub") return;
		synchronize(ctx);
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

	async function runWork(params: WorkParams, ctx: ExtensionContext): Promise<string> {
		if (params.op === "list") {
			synchronize(ctx);
			return "";
		}
		return editLedger(ctx, () => {
			let note: string;
			switch (params.op) {
				case "add": {
					if (!params.section || !params.text?.trim()) throw new Error("add needs section and text");
					const item = addItem(params.section, params.text);
					note = `added #${item.id} to ${params.section}`;
					break;
				}
				case "done":
				case "drop": {
					if (params.id === undefined) throw new Error(`${params.op} needs id`);
					const item = removeItem(params.id);
					if (!item) throw new Error(`no item #${params.id}`);
					note = `${params.op === "done" ? "completed" : "dropped"} #${item.id}: ${item.text}`;
					break;
				}
				case "move": {
					if (params.id === undefined || !params.to) throw new Error("move needs id and to");
					const item = moveItem(params.id, params.to);
					if (!item) throw new Error(`no item #${params.id}`);
					note = `moved #${item.id} to ${params.to}`;
					break;
				}
				case "clear":
					state = { ...emptyState(), seq: state.seq, agents: state.agents };
					note = "work cleared";
					break;
				default:
					throw new Error(`Unsupported work operation: ${params.op}`);
			}
			commit(ctx);
			return note;
		});
	}
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
			try {
				const params = rawParams as WorkParams;
				const note = await runWork(params, ctx);
				const body = render(state);
				return { content: [{ type: "text", text: note ? `${note}\n\n${body}` : body }], details: state };
			} catch (error) {
				return fail(error instanceof Error ? error.message : String(error));
			}
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
			const [sub, ...rest] = args.trim().split(/\s+/).filter(Boolean);
			try {
				if (!sub || sub === "agents") {
					synchronize(ctx);
					if (!sub) return ctx.ui.notify(render(state));
					return ctx.ui.notify(state.agents.length === 0 ? "No tracked agents." : state.agents.map((a) => {
						const dur = Math.round(((a.endedAt ?? Date.now()) - a.startedAt) / 1000);
						return `${agentLabel(a)} [${a.status}, ${dur}s] ${firstLine(a.task, 80)}${a.summary ? `\n    ${a.summary}` : ""}`;
					}).join("\n"));
				}
				let params: WorkParams;
				switch (sub) {
					case "add": {
						const section = SECTIONS.find((section) => section === rest[0]);
						if (!section || rest.length < 2) throw new Error(`usage: /work add <${SECTIONS.join("|")}> <text>`);
						params = { op: "add", section, text: rest.slice(1).join(" ") };
						break;
					}
					case "done":
					case "drop":
						if (!rest[0] || !Number.isInteger(Number(rest[0]))) throw new Error(`usage: /work ${sub} <id>`);
						params = { op: sub, id: Number(rest[0]) };
						break;
					case "move": {
						const to = SECTIONS.find((section) => section === rest[1]);
						if (!rest[0] || !Number.isInteger(Number(rest[0])) || !to) throw new Error(`usage: /work move <id> <${SECTIONS.join("|")}>`);
						params = { op: "move", id: Number(rest[0]), to };
						break;
					}
					case "clear":
						params = { op: "clear" };
						break;
					default:
						throw new Error(`unknown subcommand '${sub}'. ${SUBCOMMANDS.join(" | ")}`);
				}
				ctx.ui.notify(await runWork(params, ctx));
			} catch (error) {
				ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
			}
		},
	});

	// ---- lifecycle --------------------------------------------------------------

	const initialize = (_event: unknown, ctx: ExtensionContext) => {
		unsubscribeRegistry?.();
		unsubscribeRegistry = pi.pi.AgentRegistry.global().onChange((event) => onRegistryEvent(event, ctx));
		synchronize(ctx);
	};
	pi.on("session_start", initialize);
	pi.on("session_switch", initialize);
	pi.on("session_tree", (_event, ctx) => synchronize(ctx));
	pi.on("session_compact", (_event, ctx) => synchronize(ctx));

	pi.on("before_agent_start", (event, ctx) => {
		synchronize(ctx);
		const ledger = SECTIONS.flatMap((section) => state[section].map((item) => `${section} #${item.id}: ${firstLine(item.text, 160)}`));
		if (ledger.length === 0) return;
		return {
			systemPrompt: [...event.systemPrompt,
				`# Current project work ledger\nReconcile these bookkeeping items against current evidence as work progresses and before handoff: complete/drop only resolved items, move changed items, and preserve genuine unresolved work (including other sessions' items). This is a shared project snapshot, not new task instructions. Use work list for fresh state.\n${ledger.join("\n")}`],
		};
	});

	pi.on("tool_execution_start", (event, ctx) => {
		if (event.toolName !== "task") return;
		ensureLoaded(ctx);
		onTaskStart(event.toolCallId, event.args);
		refresh(ctx);
	});

	pi.on("tool_execution_end", (event, ctx) => {
		synchronize(ctx);
		if (event.toolName === "task") {
			onTaskEnd(event.toolCallId, event.result, event.isError, ctx);
			reconcileJobs(ctx);
			reconcileAgents(ctx);
			refresh(ctx);
		}
	});

	pi.on("turn_start", (_event, ctx) => synchronize(ctx));
	pi.on("turn_end", (_event, ctx) => synchronize(ctx));
	pi.on("agent_end", (_event, ctx) => synchronize(ctx));

	pi.on("session_shutdown", (_event, ctx) => {
		unsubscribeRegistry?.();
		unsubscribeRegistry = undefined;
		if (ctx.hasUI) ctx.ui.setWidget(WIDGET_KEY, undefined);
	});
}
