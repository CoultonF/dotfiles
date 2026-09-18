import type { ExtensionAPI, ExtensionContext } from "@oh-my-pi/pi-coding-agent";

// Runtime orchestration controls. The built-in Delegation prompt section is
// fixed when the session is created, so these append a stance paragraph to the
// system prompt on every request instead. Persistent changes still go through
// `omp config set task.eager <value>`.

type DelegateMode = "eager" | "normal" | "restrained";
type ConsultMode = "auto" | "off";
type Persisted = { delegate?: DelegateMode; consult?: ConsultMode };

const ENTRY_TYPE = "orchestrate";
const DELEGATE_MODES: DelegateMode[] = ["eager", "normal", "restrained"];
const CONSULT_MODES = ["auto", "off", "now"] as const;

const STANCE: Record<DelegateMode, string | undefined> = {
	eager:
		"# Delegation stance: eager\nFan out aggressively. Once the request is decomposed, dispatch every independent slice to `task` in one batch, run scouts and reviewers in parallel with your own work, and keep only integration and judgement inline.",
	normal: undefined,
	restrained:
		"# Delegation stance: restrained\nInline first. Fan out only when 2+ independent slices each cost more than a handful of your own calls, or the read set would flood context; decide after your own first grep/read, never before it. Never open with a scout. Never delegate one slice. Never babysit a lone subagent over `hub`.",
};

const CONSULT_AUTO =
	"# Advisor stance: auto\nBefore any irreversible action, architectural choice, security/auth change, or after two failed attempts at the same fix, spawn the `advisor` agent with a decision brief and weigh its answer before proceeding.";

export default function orchestrate(pi: ExtensionAPI): void {
	let delegate: DelegateMode = "normal";
	let consult: ConsultMode = "off";

	function showStatus(ctx: ExtensionContext): void {
		if (!ctx.hasUI) return;
		const parts: string[] = [];
		if (delegate !== "normal") parts.push(ctx.ui.theme.fg("accent", `delegate:${delegate}`));
		if (consult === "auto") parts.push(ctx.ui.theme.fg("accent", "consult:auto"));
		ctx.ui.setStatus(ENTRY_TYPE, parts.length > 0 ? parts.join(" ") : undefined);
	}

	function persist(ctx: ExtensionContext): void {
		pi.appendEntry<Persisted>(ENTRY_TYPE, { delegate, consult });
		showStatus(ctx);
	}

	function restore(ctx: ExtensionContext): void {
		delegate = "normal";
		consult = "off";
		for (const entry of ctx.sessionManager.getBranch()) {
			const e = entry as { type?: string; customType?: string; data?: Persisted };
			if (e.type !== "custom" || e.customType !== ENTRY_TYPE || !e.data) continue;
			if (e.data.delegate && DELEGATE_MODES.includes(e.data.delegate)) delegate = e.data.delegate;
			if (e.data.consult === "auto" || e.data.consult === "off") consult = e.data.consult;
		}
		showStatus(ctx);
	}

	pi.registerCommand("delegate", {
		description: "Delegation stance for this session: /delegate eager|normal|restrained",
		getArgumentCompletions: (prefix) => {
			const items = DELEGATE_MODES.filter((m) => m.startsWith(prefix)).map((m) => ({ value: m, label: m }));
			return items.length > 0 ? items : null;
		},
		handler: async (args, ctx) => {
			const mode = args.trim() as DelegateMode;
			if (!mode) return ctx.ui.notify(`delegate: ${delegate}`);
			if (!DELEGATE_MODES.includes(mode)) return ctx.ui.notify(`usage: /delegate ${DELEGATE_MODES.join("|")}`, "warning");
			delegate = mode;
			persist(ctx);
			ctx.ui.notify(`delegate: ${delegate} (applies from the next request)`);
		},
	});

	pi.registerCommand("consult", {
		description: "Advisor consults: /consult auto|off|now (now = ask the advisor about the current decision)",
		getArgumentCompletions: (prefix) => {
			const items = CONSULT_MODES.filter((m) => m.startsWith(prefix)).map((m) => ({ value: m, label: m }));
			return items.length > 0 ? items : null;
		},
		handler: async (args, ctx) => {
			const mode = args.trim();
			if (!mode) return ctx.ui.notify(`consult: ${consult}`);
			if (mode === "now") {
				pi.sendUserMessage(
					"Spawn the `advisor` agent now with a decision brief on the current step: context, options considered, what was tried, constraints. Weigh its answer, then continue.",
					{ deliverAs: "steer" },
				);
				return ctx.ui.notify("advisor consult requested");
			}
			if (mode !== "auto" && mode !== "off") return ctx.ui.notify(`usage: /consult ${CONSULT_MODES.join("|")}`, "warning");
			consult = mode;
			persist(ctx);
			ctx.ui.notify(`consult: ${consult}`);
		},
	});

	pi.on("session_start", (_event, ctx) => restore(ctx));
	pi.on("session_switch", (_event, ctx) => restore(ctx));

	pi.on("before_agent_start", (event) => {
		const extra = [STANCE[delegate], consult === "auto" ? CONSULT_AUTO : undefined].filter(
			(s): s is string => typeof s === "string",
		);
		if (extra.length === 0) return;
		return { systemPrompt: [...event.systemPrompt, ...extra] };
	});
}
