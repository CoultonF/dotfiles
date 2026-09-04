import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

const READ_ONLY_TOOLS: Record<string, true> = {
	read: true,
	grep: true,
	glob: true,
	lsp: true,
};

const READ_ONLY_LSP_ACTIONS: Record<string, true> = {
	diagnostics: true,
	definition: true,
	type_definition: true,
	implementation: true,
	references: true,
	hover: true,
	symbols: true,
	status: true,
	capabilities: true,
};

export default function leafInspectGuard(pi: ExtensionAPI): void {
	pi.on("tool_call", (event) => {
		if (!Object.hasOwn(READ_ONLY_TOOLS, event.toolName)) {
			return { block: true, reason: `Leaf inspection blocks tool ${event.toolName}` };
		}
		if (event.toolName !== "lsp") return;

		const action = event.input.action;
		if (typeof action === "string" && Object.hasOwn(READ_ONLY_LSP_ACTIONS, action)) return;
		return {
			block: true,
			reason: `Leaf inspection blocks mutating or administrative LSP action ${String(action)}`,
		};
	});
}
