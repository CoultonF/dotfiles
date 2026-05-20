/**
 * Auto-Commit on Exit Extension (with confirm guard)
 *
 * On session shutdown:
 *  1. Detect uncommitted changes via `git status --porcelain`.
 *  2. Build a commit message from the last assistant message.
 *  3. Confirm with the user before staging + committing.
 *
 * Skips silently when not in a git repo, when there are no changes,
 * or when the user declines the confirm dialog.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	pi.on("session_shutdown", async (_event, ctx) => {
		// Check for uncommitted changes
		const { stdout: status, code } = await pi.exec("git", ["status", "--porcelain"]);

		if (code !== 0 || status.trim().length === 0) {
			// Not a git repo or no changes
			return;
		}

		// Find the last assistant message for commit context
		const entries = ctx.sessionManager.getEntries();
		let lastAssistantText = "";
		for (let i = entries.length - 1; i >= 0; i--) {
			const entry = entries[i];
			if (entry.type === "message" && entry.message.role === "assistant") {
				const content = entry.message.content;
				if (Array.isArray(content)) {
					lastAssistantText = content
						.filter((c): c is { type: "text"; text: string } => c.type === "text")
						.map((c) => c.text)
						.join("\n");
				}
				break;
			}
		}

		const firstLine = lastAssistantText.split("\n")[0] || "Work in progress";
		const commitMessage = `[pi] ${firstLine.slice(0, 50)}${firstLine.length > 50 ? "..." : ""}`;

		// Confirm before doing anything destructive.
		// In headless / non-interactive sessions, skip the auto-commit entirely
		// (safer than silently committing without consent).
		if (!ctx.hasUI) return;

		const summary = status
			.split("\n")
			.filter((l) => l.trim().length > 0)
			.slice(0, 10)
			.join("\n");

		const confirmed = await ctx.ui.confirm(
			`Auto-commit before exit?\n\nMessage: ${commitMessage}\n\nChanges:\n${summary}`,
		);
		if (!confirmed) {
			ctx.ui.notify("Auto-commit skipped", "info");
			return;
		}

		// Stage and commit
		await pi.exec("git", ["add", "-A"]);
		const { code: commitCode } = await pi.exec("git", ["commit", "-m", commitMessage]);

		if (commitCode === 0) {
			ctx.ui.notify(`Auto-committed: ${commitMessage}`, "info");
		} else {
			ctx.ui.notify("Auto-commit failed", "error");
		}
	});
}
