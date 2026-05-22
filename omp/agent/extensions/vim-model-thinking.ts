import type {
	ExtensionAPI,
	ExtensionContext,
} from "@oh-my-pi/pi-coding-agent";
import type { ThinkingLevel } from "@oh-my-pi/pi-agent-core";

type Role = {
	label: string;
	provider: string;
	model: string;
	thinking: ThinkingLevel;
};

const ROLES: readonly Role[] = [
	{ label: "smol", provider: "openai-codex", model: "gpt-5.5", thinking: "low" },
	{ label: "default", provider: "openai-codex", model: "gpt-5.5", thinking: "medium" },
	{ label: "slow", provider: "openai-codex", model: "gpt-5.4", thinking: "xhigh" as ThinkingLevel },
];

let activeRoleIndex = 1;


function currentRoleIndex(ctx: ExtensionContext, pi: ExtensionAPI): number {
	const current = ctx.model;
	if (!current) return 1;

	const thinking = pi.getThinkingLevel();
	const exactIndex = ROLES.findIndex(
		(role) =>
			role.provider === current.provider &&
			role.model === current.id &&
			role.thinking === thinking,
	);
	if (exactIndex !== -1) return exactIndex;

	const modelIndex = ROLES.findIndex(
		(role) => role.provider === current.provider && role.model === current.id,
	);
	return modelIndex === -1 ? 1 : modelIndex;
}

function syncActiveRole(ctx: ExtensionContext, pi: ExtensionAPI): void {
	activeRoleIndex = currentRoleIndex(ctx, pi);
}

async function switchRole(
	pi: ExtensionAPI,
	ctx: ExtensionContext,
	direction: 1 | -1,
): Promise<void> {
	const nextIndex = (activeRoleIndex + direction + ROLES.length) % ROLES.length;
	const next = ROLES[nextIndex];
	const model = ctx.modelRegistry.find(next.provider, next.model);

	if (!model) {
		ctx.ui.notify(`Model not found: ${next.provider}/${next.model}`, "error");
		return;
	}

	const changed = await pi.setModel(model);
	if (!changed) {
		ctx.ui.notify(`Model unavailable: ${next.provider}/${next.model}`, "error");
		return;
	}

	activeRoleIndex = nextIndex;
	pi.setThinkingLevel(next.thinking);
	ctx.ui.notify(`Model role: ${next.label} (${next.model}, ${next.thinking})`, "info");
}

function rawDirection(data: string): 1 | -1 | 0 {
	if (data === "\x08" || data === "\x1b[104;5u") return -1;
	if (data === "\x0c" || data === "\x1b[108;5u") return 1;
	return 0;
}


function installRawRoleShortcuts(pi: ExtensionAPI, ctx: ExtensionContext): void {
	if (!ctx.hasUI) return;

	ctx.ui.onTerminalInput((data) => {
		const direction = rawDirection(data);
		if (direction === 0) return undefined;

		void switchRole(pi, ctx, direction);
		return { consume: true };
	});
}


export default function vimModelThinking(pi: ExtensionAPI): void {
	pi.registerCommand("role-prev", {
		description: "Cycle model role backward",
		handler: async (_args, ctx) => switchRole(pi, ctx, -1),
	});

	pi.registerCommand("role-next", {
		description: "Cycle model role forward",
		handler: async (_args, ctx) => switchRole(pi, ctx, 1),
	});

	pi.on("session_start", (_event, ctx) => {
		syncActiveRole(ctx, pi);
		installRawRoleShortcuts(pi, ctx);
	});

	pi.on("model_select", (_event, ctx) => syncActiveRole(ctx, pi));
	pi.on("thinking_level_select", (_event, ctx) => syncActiveRole(ctx, pi));
}
