import type {
	ExtensionAPI,
	ExtensionContext,
	Theme,
} from "@mariozechner/pi-coding-agent";
import { VERSION } from "@mariozechner/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";

const LOGO_BITMAP = [
	[1, 1, 1, 0],
	[1, 0, 1, 0],
	[1, 1, 0, 1],
	[1, 0, 0, 1],
];

const SMALL_ICON = ["██████  ", "██  ██  ", "████  ██", "██    ██"];

function center(line: string, width: number): string {
	const padding = Math.max(0, Math.floor((width - visibleWidth(line)) / 2));
	return truncateToWidth(" ".repeat(padding) + line, width, "");
}

function shortModel(ctx: ExtensionContext): string {
	const model = ctx.model;
	if (!model) return "model ready";
	return `${model.provider}/${model.id}`;
}

function renderIcon(cellWidth: number, cellHeight: number): string[] {
	return LOGO_BITMAP.flatMap((row) => {
		const line = row
			.map((filled) => (filled ? "█".repeat(cellWidth) : " ".repeat(cellWidth)))
			.join("");
		return Array.from({ length: cellHeight }, () => line);
	});
}

function iconForWidth(width: number): string[] {
	if (width >= 64) return renderIcon(6, 2);
	if (width >= 36) return renderIcon(4, 1);
	return SMALL_ICON;
}

function tetrisIcon(theme: Theme, width: number): string[] {
	const color = (line: string) => theme.bold(theme.fg("accent", line));
	return iconForWidth(width).map(color);
}

function installStartScreen(ctx: ExtensionContext): void {
	if (!ctx.hasUI) return;

	ctx.ui.setHeader((_tui, theme) => ({
		invalidate() {},
		render(width: number): string[] {
			const icon = tetrisIcon(theme, width);
			const title = theme.bold(theme.fg("text", "pi coding agent"));
			const version = theme.fg("muted", `v${VERSION}`);
			const model = theme.fg("muted", shortModel(ctx));
			const hint = theme.fg("muted", "/ commands  ·  ! shell  ·  ctrl+c exit");

			return [
				"",
				"",
				...icon.map((line) => center(line, width)),
				"",
				center(title, width),
				center(version, width),
				"",
				center(model, width),
				center(hint, width),
				"",
			];
		},
	}));
}

export default function piStartScreen(pi: ExtensionAPI): void {
	pi.on("session_start", (_event, ctx) => {
		installStartScreen(ctx);
	});

	pi.registerCommand("pi-start-screen", {
		description: "Show the minimal Tetris-style Pi startup header",
		handler: async (_args, ctx) => {
			installStartScreen(ctx);
		},
	});

	pi.registerCommand("default-header", {
		description: "Restore Pi's built-in startup header",
		handler: async (_args, ctx) => {
			ctx.ui.setHeader(undefined);
		},
	});
}
