import path from "node:path";
import type { CustomToolFactory } from "@oh-my-pi/pi-coding-agent";

const INTENT_SKILL_PATTERN = /^(@?[a-z0-9][a-z0-9._~-]*(?:\/[a-z0-9][a-z0-9._~-]*)?)#[a-z0-9][a-z0-9._~/-]*$/i;

function resolveRelativeCwd(baseCwd: string, requestedCwd?: string): string {
	if (!requestedCwd) return baseCwd;
	if (path.isAbsolute(requestedCwd)) {
		throw new Error("cwd must be relative to the current OMP workspace");
	}

	const resolved = path.resolve(baseCwd, requestedCwd);
	const relative = path.relative(baseCwd, resolved);
	if (relative === "" || (!relative.startsWith("..") && !path.isAbsolute(relative))) {
		return resolved;
	}

	throw new Error("cwd must stay inside the current OMP workspace");
}

const factory: CustomToolFactory = (pi) => {
	const z = pi.zod;

	return {
		name: "tanstack_intent",
		label: "TanStack Intent",
		strict: true,
		description:
			"Read-only TanStack Intent skill discovery/loader. Supports only `list` and `load` for plan-safe use; mutating Intent commands are intentionally unavailable.",
		parameters: z.object({
			command: z.enum(["list", "load"]).describe("Read-only TanStack Intent command to run"),
			skill: z
				.string()
				.optional()
				.describe("Skill identifier for load, formatted like @tanstack/react-query#core"),
			cwd: z
				.string()
				.optional()
				.describe("Optional working directory, relative to the current OMP workspace"),
			json: z
				.boolean()
				.optional()
				.describe("For list only, pass --json to TanStack Intent"),
		}),

		async execute(_toolCallId, params, _onUpdate, _ctx, signal) {
			let cwd: string;
			try {
				cwd = resolveRelativeCwd(pi.cwd, params.cwd);
			} catch (error) {
				return {
					content: [{ type: "text", text: error instanceof Error ? error.message : String(error) }],
					isError: true,
					details: { command: params.command, cwd: params.cwd },
				};
			}

			const args = ["@tanstack/intent@latest", params.command];

			if (params.command === "load") {
				if (!params.skill || !INTENT_SKILL_PATTERN.test(params.skill)) {
					return {
						content: [
							{
								type: "text",
								text: "load requires a skill formatted like @tanstack/react-query#core",
							},
						],
						isError: true,
						details: { command: params.command, cwd },
					};
				}
				if (params.json) {
					return {
						content: [{ type: "text", text: "json is only supported with the list command" }],
						isError: true,
						details: { command: params.command, cwd, skill: params.skill },
					};
				}
				args.push(params.skill);
			} else {
				if (params.skill) {
					return {
						content: [{ type: "text", text: "skill is only supported with the load command" }],
						isError: true,
						details: { command: params.command, cwd, skill: params.skill },
					};
				}
				if (params.json) args.push("--json");
			}

			const result = await pi.exec("bunx", args, { cwd, signal, timeout: 120_000 });
			const details = {
				command: params.command,
				cwd,
				skill: params.skill,
				json: params.json === true,
				code: result.code,
				killed: result.killed,
			};

			if (result.code !== 0) {
				const text = [
					`bunx @tanstack/intent@latest ${params.command} failed with exit code ${result.code}`,
					result.killed ? "Process was killed." : undefined,
					result.stderr ? `stderr:\n${result.stderr.trimEnd()}` : undefined,
					result.stdout ? `stdout:\n${result.stdout.trimEnd()}` : undefined,
				]
					.filter(Boolean)
					.join("\n\n");

				return {
					content: [{ type: "text", text }],
					isError: true,
					details,
				};
			}

			return {
				content: [{ type: "text", text: result.stdout }],
				details,
			};
		},
	};
};

export default factory;
