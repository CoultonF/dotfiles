import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";

const STATUS_ID = "git-status";
const REFRESH_MS = 10_000;

export default function (pi: ExtensionAPI) {
	let interval: ReturnType<typeof setInterval> | undefined;
	let refreshTimeout: ReturnType<typeof setTimeout> | undefined;
	let lastText: string | undefined;
	let running = false;
	let pending = false;

	async function getGitStatus() {
		const branchResult = await pi.exec("git", ["branch", "--show-current"], { timeout: 2_000 });
		if (branchResult.code !== 0) return undefined;

		let branch = branchResult.stdout.trim();
		if (!branch) {
			const headResult = await pi.exec("git", ["rev-parse", "--short", "HEAD"], { timeout: 2_000 });
			if (headResult.code !== 0) return undefined;
			branch = headResult.stdout.trim();
		}

		const statusResult = await pi.exec("git", ["status", "--porcelain=v1", "--untracked-files=all"], {
			timeout: 2_000,
		});
		if (statusResult.code !== 0) return undefined;

		const count = statusResult.stdout.split("\n").filter((line) => line.trim().length > 0).length;
		return { branch, count };
	}

	async function refresh(ctx: ExtensionContext) {
		if (!ctx.hasUI) return;
		if (running) {
			pending = true;
			return;
		}

		running = true;
		try {
			const status = await getGitStatus();
			const text = status
				? `${ctx.ui.theme.fg("accent", ` ${status.branch}`)} ${ctx.ui.theme.fg(
						status.count === 0 ? "success" : "warning",
						`±${status.count}`,
					)}`
				: undefined;

			if (text !== lastText) {
				ctx.ui.setStatus(STATUS_ID, text);
				lastText = text;
			}
		} finally {
			running = false;
			if (pending) {
				pending = false;
				queueRefresh(ctx, 250);
			}
		}
	}

	function queueRefresh(ctx: ExtensionContext, delay = 750) {
		if (refreshTimeout) clearTimeout(refreshTimeout);
		refreshTimeout = setTimeout(() => {
			refreshTimeout = undefined;
			void refresh(ctx);
		}, delay);
	}

	pi.on("session_start", async (_event, ctx) => {
		await refresh(ctx);
		interval = setInterval(() => void refresh(ctx), REFRESH_MS);
	});

	pi.on("tool_result", async (event, ctx) => {
		if (["bash", "edit", "write"].includes(event.toolName)) {
			queueRefresh(ctx);
		}
	});

	pi.on("turn_end", async (_event, ctx) => {
		queueRefresh(ctx, 250);
	});

	pi.on("session_shutdown", async (_event, ctx) => {
		if (interval) clearInterval(interval);
		if (refreshTimeout) clearTimeout(refreshTimeout);
		ctx.ui.setStatus(STATUS_ID, undefined);
	});
}
