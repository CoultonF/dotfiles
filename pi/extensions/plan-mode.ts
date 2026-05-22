type ExtensionAPI = any;
type ExtensionContext = any;
type AgentMessage = any;
type AssistantMessage = any;
type TextContent = { type: "text"; text: string };

interface PlanStep {
	step: number;
	text: string;
	completed: boolean;
}

interface PlanModeState {
	enabled: boolean;
	executing: boolean;
	steps: PlanStep[];
	previousTools?: string[];
	deepPlanningRequested?: boolean;
}

const PLAN_MODE_TOOL_CANDIDATES = [
	"read",
	"bash",
	"mcp",
	"subagent",
	"intercom",
	"contact_supervisor",
	"tanstack_intent",
	"web_search",
	"code_search",
	"fetch_content",
	"get_search_content",
	"ask_user_question",
	"todo",
	"ast_grep_search",
	"lsp_navigation",
	"lsp_diagnostics",
	"ctx_batch_execute",
	"ctx_search",
	"ctx_execute",
	"ctx_execute_file",
];

const READ_ONLY_BASH_ALLOWLIST = [
	/^\s*(pwd|ls|find|grep|rg|fd|cat|head|tail|wc|sort|uniq|diff|file|stat|du|df|tree|which|type|env|printenv|uname|whoami|id|date|ps)\b/i,
	/^\s*git\s+(status|log|diff|show|branch|remote|config\s+--get|ls-files)\b/i,
	/^\s*(npm|bun|yarn|pnpm)\s+(list|ls|view|info|search|outdated|audit)\b/i,
	/^\s*bunx\b.*\btanstack\b.*\bintent\b/i,
	/^\s*bunx\b.*\bintent\b.*\btanstack\b/i,
];

const DESTRUCTIVE_BASH_PATTERNS = [
	/\b(rm|rmdir|mv|cp|mkdir|touch|chmod|chown|ln|tee|truncate|dd|shred)\b/i,
	/(^|[^<])>(?!>)/,
	/>>/,
	/\b(npm|bun|yarn|pnpm)\s+(install|add|remove|uninstall|update|ci|link|publish)\b/i,
	/\bgit\s+(add|commit|push|pull|merge|rebase|reset|checkout|switch|stash|cherry-pick|revert|tag|init|clone)\b/i,
	/\b(sudo|su|kill|pkill|killall|reboot|shutdown)\b/i,
];

function isAssistantMessage(
	message: AgentMessage,
): message is AssistantMessage {
	return message.role === "assistant" && Array.isArray(message.content);
}

function getAssistantText(message: AssistantMessage): string {
	return message.content
		.filter((block: any): block is TextContent => block.type === "text")
		.map((block: TextContent) => block.text)
		.join("\n");
}

function getAvailableToolNames(pi: ExtensionAPI): Set<string> {
	return new Set(pi.getAllTools().map((tool: { name: string }) => tool.name));
}

function getPlanTools(pi: ExtensionAPI): string[] {
	const available = getAvailableToolNames(pi);
	const explicitTools = PLAN_MODE_TOOL_CANDIDATES.filter((tool) =>
		available.has(tool),
	);
	const tanstackIntentTools = [...available].filter(
		(tool) =>
			/tanstack.*intent|intent.*tanstack/i.test(tool) &&
			!explicitTools.includes(tool),
	);
	return [...explicitTools, ...tanstackIntentTools];
}

function cleanStepText(text: string): string {
	return text
		.replace(/\*{1,2}([^*]+)\*{1,2}/g, "$1")
		.replace(/`([^`]+)`/g, "$1")
		.replace(/\s+/g, " ")
		.trim();
}

function extractPlanSteps(text: string): PlanStep[] {
	const header = text.match(/^\s*\*{0,2}Plan:\*{0,2}\s*$/im);
	if (!header?.index && header?.index !== 0) return [];

	const planText = text.slice(header.index + header[0].length);
	const steps: PlanStep[] = [];
	for (const match of planText.matchAll(/^\s*(\d+)[.)]\s+(.+)$/gm)) {
		const stepText = cleanStepText(match[2]);
		if (stepText.length > 3) {
			steps.push({ step: steps.length + 1, text: stepText, completed: false });
		}
	}
	return steps;
}

function markCompletedSteps(text: string, steps: PlanStep[]): boolean {
	let changed = false;
	for (const match of text.matchAll(/\[DONE:(\d+)\]/gi)) {
		const stepNumber = Number(match[1]);
		const step = steps.find((item) => item.step === stepNumber);
		if (step && !step.completed) {
			step.completed = true;
			changed = true;
		}
	}
	return changed;
}

function isSafePlanBash(command: string): boolean {
	return (
		!DESTRUCTIVE_BASH_PATTERNS.some((pattern) => pattern.test(command)) &&
		READ_ONLY_BASH_ALLOWLIST.some((pattern) => pattern.test(command))
	);
}

export default function planModeExtension(pi: ExtensionAPI): void {
	let planModeEnabled = false;
	let executionMode = false;
	let planSteps: PlanStep[] = [];
	let previousTools: string[] | undefined;
	let deepPlanningRequested = false;

	function persistState(): void {
		pi.appendEntry("plan-mode", {
			enabled: planModeEnabled,
			executing: executionMode,
			steps: planSteps,
			previousTools,
			deepPlanningRequested,
		});
	}

	function restoreTools(): void {
		if (previousTools?.length) {
			const available = getAvailableToolNames(pi);
			const tools = previousTools.filter((tool) => available.has(tool));
			if (tools.length > 0) {
				pi.setActiveTools(tools);
				return;
			}
		}
		pi.setActiveTools(
			pi.getAllTools().map((tool: { name: string }) => tool.name),
		);
	}

	function updateUi(ctx: ExtensionContext): void {
		ctx.ui.setWidget("plan-mode", undefined);

		if (executionMode && planSteps.length > 0) {
			const completed = planSteps.filter((step) => step.completed).length;
			ctx.ui.setStatus(
				"plan-mode",
				ctx.ui.theme.fg("accent", `📋 ${completed}/${planSteps.length}`),
			);
			return;
		}

		ctx.ui.setStatus(
			"plan-mode",
			planModeEnabled ? ctx.ui.theme.fg("warning", "⏸ plan") : undefined,
		);
	}

	function enablePlanMode(ctx: ExtensionContext): void {
		previousTools = pi.getActiveTools();
		planModeEnabled = true;
		executionMode = false;
		planSteps = [];
		deepPlanningRequested = false;
		const planTools = getPlanTools(pi);
		pi.setActiveTools(planTools);
		ctx.ui.notify(`Plan mode enabled. Tools: ${planTools.join(", ")}`, "info");
		updateUi(ctx);
		persistState();
	}

	function disablePlanMode(ctx: ExtensionContext): void {
		planModeEnabled = false;
		executionMode = false;
		planSteps = [];
		deepPlanningRequested = false;
		restoreTools();
		ctx.ui.notify("Plan mode disabled. Full tool access restored.", "info");
		updateUi(ctx);
		persistState();
	}

	function togglePlanMode(ctx: ExtensionContext): void {
		if (planModeEnabled || executionMode) {
			disablePlanMode(ctx);
		} else {
			enablePlanMode(ctx);
		}
	}

	function requestDeepPlanning(ctx: ExtensionContext): void {
		if (!planModeEnabled) {
			enablePlanMode(ctx);
		}
		deepPlanningRequested = true;
		persistState();
		pi.sendUserMessage(`Use deep plan mode for this request.

If the subagent tool is available, delegate read-only planning work to background agents before finalizing the plan:
1. Ask one agent to identify relevant files and existing patterns.
2. Ask one agent to identify risks, edge cases, and unknowns.
3. Ask one agent to propose validation steps.

Tell every planning subagent to remain in plan mode: read-only exploration only, no file mutations, no package installs, no commits, and no execution of implementation steps. If intercom/contact_supervisor is available, tell subagents to report plan-changing discoveries, blockers, and decisions back to the planning supervisor instead of continuing silently.

Synthesize their findings into one final numbered Plan:. Use ask_user_question for any missing requirements and todo to track planning work.`);
	}

	pi.registerFlag("plan", {
		description: "Start in plan mode",
		type: "boolean",
		default: false,
	});

	pi.registerCommand("plan", {
		description: "Toggle plan mode",
		handler: async (_args: string, ctx: ExtensionContext) =>
			togglePlanMode(ctx),
	});

	pi.registerCommand("plan-deep", {
		description: "Enable plan mode and ask subagents for background planning",
		handler: async (_args: string, ctx: ExtensionContext) =>
			requestDeepPlanning(ctx),
	});

	pi.registerShortcut("shift+tab", {
		description: "Toggle plan mode",
		handler: async (ctx: ExtensionContext) => togglePlanMode(ctx),
	});

	pi.on("tool_call", async (event: any) => {
		if (!planModeEnabled || event.toolName !== "bash") return;
		const command =
			typeof event.input.command === "string" ? event.input.command : "";
		if (!isSafePlanBash(command)) {
			return {
				block: true,
				reason: `Plan mode blocks mutating or unrecognized bash commands. Use read-only tools or press Shift+Tab to leave plan mode.\nCommand: ${command}`,
			};
		}
	});

	pi.on("before_agent_start", async () => {
		if (planModeEnabled) {
			const availableTools = getAvailableToolNames(pi);
			const hasIntercom =
				availableTools.has("intercom") ||
				availableTools.has("contact_supervisor");
			const intercomGuidance = hasIntercom
				? "\n- Use intercom for coordination with other planning sessions. Subagents with contact_supervisor should send progress_update for plan-changing discoveries and need_decision/interview_request when blocked or needing supervisor input."
				: "";
			const subagentGuidance = availableTools.has("subagent")
				? `\n- For broad or risky work, use the subagent tool to delegate read-only background planning. Prefer parallel research agents for relevant files/patterns, risks/edge cases, and validation strategy. Explicitly instruct every planning subagent to remain in plan mode: read-only exploration only, no file mutations, no package installs, no commits, and no implementation execution.${hasIntercom ? " Tell subagents to communicate plan-changing findings, blockers, and decisions back through contact_supervisor/intercom." : ""}${deepPlanningRequested ? " Deep planning was explicitly requested, so use subagents before finalizing unless the task is trivial." : ""}`
				: "";
			const todoGuidance = availableTools.has("todo")
				? "\n- Use todo to track planning tasks. Once a Plan: is finalized, create or update todo entries that mirror the numbered plan steps."
				: "";
			const questionGuidance = availableTools.has("ask_user_question")
				? "\n- Use ask_user_question when requirements, tradeoffs, or approval choices are ambiguous."
				: "";
			const hasTanstackIntent = [...availableTools].some((tool) =>
				/tanstack.*intent|intent.*tanstack/i.test(tool),
			);
			const tanstackGuidance = hasTanstackIntent
				? "\n- Use TanStack intent tools when planning TanStack-related implementation. bunx commands for TanStack intent are allowed only for read-only intent/planning exploration."
				: "";
			const hasWebAccess = [
				"web_search",
				"code_search",
				"fetch_content",
				"get_search_content",
			].some((tool) => availableTools.has(tool));
			const webGuidance = hasWebAccess
				? "\n- Use web_search/code_search/fetch_content/get_search_content for current documentation, API references, and external research needed to plan safely."
				: "";
			return {
				message: {
					customType: "plan-mode-context",
					content: `[PLAN MODE ACTIVE]
You are in read-only planning mode.

Rules:
- Do not modify files, install packages, commit changes, or run destructive commands.
- Use read-only exploration tools only.${questionGuidance}${todoGuidance}${intercomGuidance}${subagentGuidance}${tanstackGuidance}${webGuidance}
- Prefer pi-lens tools such as ast_grep_search, lsp_navigation, and lsp_diagnostics for code understanding when available.
- Finalize your plan as a numbered list under an exact "Plan:" header.
- Include validation in the plan unless the user explicitly says not to.
- Do not execute the plan until the user chooses Execute.`,
					display: false,
				},
			};
		}

		if (executionMode && planSteps.length > 0) {
			const remainingSteps = planSteps.filter((step) => !step.completed);
			return {
				message: {
					customType: "plan-execution-context",
					content: `[EXECUTING APPROVED PLAN]
Execute the approved plan using the available tools.

Remaining steps:
${remainingSteps.map((step) => `${step.step}. ${step.text}`).join("\n")}

Use todo to keep execution progress aligned with these steps when the todo tool is available.
After completing each step, include [DONE:n] in your response for that step number.`,
					display: false,
				},
			};
		}
	});

	pi.on("turn_end", async (event: any, ctx: ExtensionContext) => {
		if (
			!executionMode ||
			planSteps.length === 0 ||
			!isAssistantMessage(event.message)
		)
			return;
		if (markCompletedSteps(getAssistantText(event.message), planSteps)) {
			updateUi(ctx);
			persistState();
		}
	});

	pi.on("agent_end", async (event: any, ctx: ExtensionContext) => {
		if (executionMode && planSteps.length > 0) {
			if (planSteps.every((step) => step.completed)) {
				pi.sendMessage(
					{
						customType: "plan-mode-complete",
						content: `Plan complete.\n\n${planSteps.map((step) => `✓ ${step.text}`).join("\n")}`,
						display: true,
					},
					{ triggerTurn: false },
				);
				executionMode = false;
				planSteps = [];
				restoreTools();
				updateUi(ctx);
				persistState();
			}
			return;
		}

		if (!planModeEnabled || !ctx.hasUI) return;

		const lastAssistant = [...event.messages]
			.reverse()
			.find(isAssistantMessage);
		const extractedSteps = lastAssistant
			? extractPlanSteps(getAssistantText(lastAssistant))
			: [];
		if (extractedSteps.length === 0) return;

		planSteps = extractedSteps;
		pi.sendMessage(
			{
				customType: "plan-mode-plan",
				content: `Plan finalized with ${planSteps.length} steps.\n\n${planSteps.map((step) => `${step.step}. ${step.text}`).join("\n")}`,
				display: true,
			},
			{ triggerTurn: false },
		);

		const planActions = ["Execute the plan", "Ask for a revision"];
		if (getAvailableToolNames(pi).has("subagent")) {
			planActions.push("Deepen with subagents");
		}
		const choice = await ctx.ui.select(
			"Plan finalized. What next?",
			planActions,
		);
		if (choice === "Execute the plan") {
			planModeEnabled = false;
			executionMode = true;
			restoreTools();
			updateUi(ctx);
			persistState();
			pi.sendMessage(
				{
					customType: "plan-mode-execute",
					content: `Execute the approved plan. Use todo to mirror and update these steps when available.\n\n${planSteps.map((step) => `${step.step}. ${step.text}`).join("\n")}`,
					display: true,
				},
				{ triggerTurn: true },
			);
		} else if (choice === "Deepen with subagents") {
			deepPlanningRequested = true;
			persistState();
			pi.sendUserMessage(
				`Deepen this plan before execution. Use the subagent tool to delegate read-only background planning to parallel agents for: relevant files and patterns; risks and edge cases; validation strategy. Instruct every subagent to remain in plan mode: read-only exploration only, no file mutations, no package installs, no commits, and no implementation execution. If contact_supervisor/intercom is available, require subagents to send progress_update for plan-changing discoveries and need_decision/interview_request when blocked. Then synthesize an improved final Plan:.`,
			);
		} else if (choice === "Ask for a revision") {
			const revision = await ctx.ui.editor(
				"Revision request",
				"Revise the plan to...",
			);
			if (revision?.trim()) {
				persistState();
				pi.sendUserMessage(revision.trim());
			}
		}
	});

	pi.on("session_start", async (_event: any, ctx: ExtensionContext) => {
		const branch = ctx.sessionManager.getBranch();
		const lastState = [...branch]
			.reverse()
			.find(
				(entry: { type: string; customType?: string }) =>
					entry.type === "custom" && entry.customType === "plan-mode",
			) as { data?: PlanModeState } | undefined;

		if (lastState?.data) {
			planModeEnabled = lastState.data.enabled;
			executionMode = lastState.data.executing;
			planSteps = lastState.data.steps ?? [];
			previousTools = lastState.data.previousTools;
			deepPlanningRequested = lastState.data.deepPlanningRequested ?? false;
		} else if (pi.getFlag("plan") === true) {
			planModeEnabled = true;
		}

		if (planModeEnabled) {
			previousTools ??= pi.getActiveTools();
			pi.setActiveTools(getPlanTools(pi));
		}
		updateUi(ctx);
	});
}
