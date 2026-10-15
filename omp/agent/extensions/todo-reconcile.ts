import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

// Native todos already own mid-run and bounded stop-time reminders. Supply the
// missing next-request snapshot without starting another continuation loop.
export default function todoReconcile(pi: ExtensionAPI): void {
	pi.on("before_agent_start", (_event, ctx) => {
		const phases = pi.pi.getLatestTodoPhasesFromEntries(ctx.sessionManager.getBranch());
		const unfinished = phases
			.map((phase) => ({
				name: phase.name,
				tasks: phase.tasks.filter(
					(task) => task.status === "pending" || task.status === "in_progress" || task.status === "blocked",
				),
			}))
			.filter((phase) => phase.tasks.length > 0);
		if (unfinished.length === 0) return;

		return {
			message: {
				customType: "todo-reconcile",
				display: false,
				content: [
					"<system-reminder>",
					"Current unfinished native todos on this session branch at request start:",
					JSON.stringify(unfinished, null, 2),
					"Before handoff, reconcile todo statuses with actual progress using the native todo operations. Mark only genuinely finished work complete; keep unresolved and blocked items, including their blocker notes. Do not clear or replace the list merely to make it look finished. If no todo operation is available, explicitly report the unresolved items instead.",
					"These are existing bookkeeping items, not a request to resume unrelated work. Follow the current user request; later todo changes supersede this snapshot.",
					"</system-reminder>",
				].join("\n\n"),
			},
		};
	});
}
