import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";

function shortModel(id: string | undefined): string {
	return id?.split("/").at(-1) || "model";
}

function compactStatus(statuses: ReadonlyMap<string, string>): string {
	return [...statuses.entries()]
		.filter(([id]) => id !== "codex-ui")
		.map(([, value]) => value)
		.join("  ");
}

function installCodexUi(ctx: ExtensionContext): void {
	ctx.ui.setWorkingIndicator({
		frames: [
			ctx.ui.theme.fg("dim", "•"),
			ctx.ui.theme.fg("muted", "•"),
			ctx.ui.theme.fg("accent", "•"),
			ctx.ui.theme.fg("muted", "•"),
		],
		intervalMs: 180,
	});

	ctx.ui.setFooter((tui, theme, footerData) => {
		const dispose = footerData.onBranchChange(() => tui.requestRender());

		return {
			dispose,
			invalidate() {},
			render(width: number): string[] {
				const branch = footerData.getGitBranch();
				const statuses = compactStatus(footerData.getExtensionStatuses());
				const leftParts = [theme.fg("accent", shortModel(ctx.model?.id))];
				if (branch) leftParts.push(theme.fg("muted", branch));
				const left = leftParts.join(theme.fg("dim", "  "));
				const right = statuses ? theme.fg("dim", statuses) : theme.fg("dim", "ready");
				const gap = " ".repeat(Math.max(1, width - visibleWidth(left) - visibleWidth(right)));
				return [truncateToWidth(left + gap + right, width, "")];
			},
		};
	});
}

export default function codexUi(pi: ExtensionAPI): void {
	pi.on("session_start", (_event, ctx) => {
		installCodexUi(ctx);
	});
}
