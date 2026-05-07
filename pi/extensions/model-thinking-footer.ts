import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { truncateToWidth } from "@mariozechner/pi-tui";

function installFooter(pi: ExtensionAPI, ctx: ExtensionContext) {
	if (!ctx.hasUI) return;

	ctx.ui.setFooter((_tui, theme, footerData) => ({
		dispose: footerData.onBranchChange(() => _tui.requestRender()),
		invalidate() {},
		render(width: number): string[] {
			const statuses = Array.from(footerData.getExtensionStatuses().values()).filter(Boolean);
			const model = ctx.model?.id ?? "no-model";
			const thinking = pi.getThinkingLevel();
			const modelStatus = `${theme.fg("accent", model)} ${theme.fg("warning", thinking)}`;
			const line = [...statuses, modelStatus].join("  ");

			return [truncateToWidth(line, width)];
		},
	}));
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		installFooter(pi, ctx);
	});

	pi.on("model_select", async (_event, ctx) => {
		installFooter(pi, ctx);
	});

	pi.on("thinking_level_select", async (_event, ctx) => {
		installFooter(pi, ctx);
	});

	pi.on("session_shutdown", async (_event, ctx) => {
		ctx.ui.setFooter(undefined);
	});
}
