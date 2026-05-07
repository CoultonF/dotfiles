import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";

function installFooter(pi: ExtensionAPI, ctx: ExtensionContext) {
	if (!ctx.hasUI) return;

	ctx.ui.setFooter((_tui, theme, footerData) => ({
		dispose: footerData.onBranchChange(() => _tui.requestRender()),
		invalidate() {},
		render(width: number): string[] {
			const statuses = Array.from(footerData.getExtensionStatuses().values()).filter(Boolean).join("  ");
			const model = ctx.model?.id ?? "no-model";
			const thinking = pi.getThinkingLevel();
			const right = theme.fg("dim", `${model} ${thinking}`);
			const left = statuses || theme.fg("dim", footerData.getGitBranch() ?? "no git");
			const pad = " ".repeat(Math.max(1, width - visibleWidth(left) - visibleWidth(right)));

			return [truncateToWidth(left + pad + right, width)];
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
