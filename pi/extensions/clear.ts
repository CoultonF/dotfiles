import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function clearCommand(pi: ExtensionAPI): void {
	pi.registerCommand("clear", {
		description: "Start a new session, same as /new",
		handler: async (_args, ctx) => {
			await ctx.newSession({
				parentSession: ctx.sessionManager.getSessionFile(),
			});
		},
	});
}
