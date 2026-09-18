import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

// Some terminals send legacy \x08 for Ctrl+H; rewrite it to the CSI-u form OMP binds.
export default function ctrlHFix(pi: ExtensionAPI): void {
	pi.on("session_start", (_event, ctx) => {
		if (!ctx.hasUI) return;
		ctx.ui.onTerminalInput((data) => (data === "\x08" ? { data: "\x1b[104;5u" } : undefined));
	});
}
