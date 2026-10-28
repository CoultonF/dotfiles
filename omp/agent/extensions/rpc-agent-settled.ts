import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

// In `--mode rpc`, write one `agent_settled` frame after each terminal
// `agent_end` so a host can wait on a single small line instead of parsing the
// full `agent_end` payload. `aborted` is true when the run's last assistant
// message stopped with reason "aborted" (host sent `abort`, or Escape).
// Non-terminal ends (retry, compaction continuation, pending async delivery)
// are skipped: the agent has not settled yet. Stdout is the RPC channel, so
// the frame is written as a single line, like OMP's own frames.
export default function rpcAgentSettled(pi: ExtensionAPI): void {
	pi.on("agent_end", (event, ctx) => {
		if (ctx.mode !== "rpc") return;
		if (event.willContinue) return;
		const last = [...event.messages].reverse().find((message) => message.role === "assistant");
		const aborted = last?.role === "assistant" && last.stopReason === "aborted";
		process.stdout.write(`${JSON.stringify({ type: "agent_settled", aborted })}\n`);
	});
}
