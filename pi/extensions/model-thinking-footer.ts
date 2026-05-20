import type {
	ExtensionAPI,
	ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { truncateToWidth } from "@earendil-works/pi-tui";

function installFooter(pi: ExtensionAPI, ctx: ExtensionContext): void {
	if (!ctx.hasUI) return;

	ctx.ui.setFooter((tui, _theme, footerData) => {
		const dispose = footerData.onBranchChange(() => tui.requestRender());

		return {
			dispose,
			invalidate() {},
			render(width: number): string[] {
				const theme = ctx.ui.theme;
				const statuses = Array.from(
					footerData.getExtensionStatuses().values(),
				).filter(Boolean);
				const model = ctx.model?.id ?? "no-model";
				const thinking = pi.getThinkingLevel();
				const modelStatus = `${theme.fg("accent", model)} ${theme.fg("warning", thinking)}`;
				const line = [...statuses, modelStatus].join("  ");

				return [truncateToWidth(line, width)];
			},
		};
	});
}

export default function modelThinkingFooter(pi: ExtensionAPI): void {
	pi.on("session_start", (_event, ctx) => {
		installFooter(pi, ctx);
	});

	pi.on("model_select", (_event, ctx) => {
		installFooter(pi, ctx);
	});

	pi.on("thinking_level_select", (_event, ctx) => {
		installFooter(pi, ctx);
	});

	pi.on("session_shutdown", (_event, ctx) => {
		ctx.ui.setFooter(undefined);
	});
}
