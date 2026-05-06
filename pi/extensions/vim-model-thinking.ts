import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";

type ThinkingLevel = "off" | "minimal" | "low" | "medium" | "high" | "xhigh";

const THINKING_LEVELS: ThinkingLevel[] = ["off", "minimal", "low", "medium", "high", "xhigh"];

function getAvailableThinkingLevels(ctx: ExtensionContext): ThinkingLevel[] {
	const model = ctx.model;
	if (!model?.reasoning) return ["off"];
	return THINKING_LEVELS.filter((level) => model.thinkingLevelMap?.[level] !== null);
}

function moveThinking(pi: ExtensionAPI, ctx: ExtensionContext, direction: 1 | -1): void {
	const levels = getAvailableThinkingLevels(ctx);
	if (levels.length <= 1) {
		ctx.ui.notify("Current model does not support multiple thinking levels", "info");
		return;
	}

	const current = pi.getThinkingLevel() as ThinkingLevel;
	const index = levels.includes(current) ? levels.indexOf(current) : 0;
	const next = levels[(index + direction + levels.length) % levels.length];
	pi.setThinkingLevel(next);
	ctx.ui.notify(`Thinking: ${pi.getThinkingLevel()}`, "info");
}

export default function vimModelThinking(pi: ExtensionAPI): void {
	pi.registerShortcut("ctrl+h", {
		description: "Decrease thinking level",
		handler: (ctx) => moveThinking(pi, ctx, -1),
	});

	pi.registerShortcut("ctrl+l", {
		description: "Increase thinking level",
		handler: (ctx) => moveThinking(pi, ctx, 1),
	});
}
