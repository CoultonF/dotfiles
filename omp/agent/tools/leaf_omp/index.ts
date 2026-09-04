import { realpath, stat } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import type { CustomToolFactory } from "@oh-my-pi/pi-coding-agent";
import { RpcClient } from "@oh-my-pi/pi-coding-agent/modes/rpc/rpc-client";

type WorkerMode = "inspect" | "implement";

type Worker = {
	client: RpcClient;
	queue: Promise<void>;
	root: string;
	mode: WorkerMode;
	additionalDirectories: readonly string[];
};

type WorkerEntry = {
	key: string;
	promise: Promise<Worker>;
	reused: boolean;
};

const DEFAULT_TIMEOUT_SECONDS = 900;
const workers = new Map<string, Promise<Worker>>();
const INSPECT_GUARD_PATH = fileURLToPath(new URL("./inspect-guard.ts", import.meta.url));

async function canonicalDirectory(
	workspaceRoot: string,
	requested: string,
	label: string,
): Promise<string> {
	if (path.isAbsolute(requested)) {
		throw new Error(`${label} must be relative to the current OMP workspace`);
	}

	const resolved = await realpath(path.resolve(workspaceRoot, requested));
	const relative = path.relative(workspaceRoot, resolved);
	if (
		relative !== "" &&
		(relative.startsWith(`..${path.sep}`) || relative === ".." || path.isAbsolute(relative))
	) {
		throw new Error(`${label} must stay inside the current OMP workspace`);
	}

	const metadata = await stat(resolved);
	if (!metadata.isDirectory()) {
		throw new Error(`${label} is not a directory: ${requested}`);
	}
	return resolved;
}

async function resolveAdditionalDirectories(
	workspaceRoot: string,
	leafRoot: string,
	requested: readonly string[] | undefined,
): Promise<string[]> {
	const resolved = await Promise.all(
		(requested ?? []).map((input) =>
			canonicalDirectory(workspaceRoot, input, "additional directory"),
		),
	);

	return [...new Set(resolved.filter((directory) => directory !== leafRoot))].sort();
}

async function startWorker(
	root: string,
	additionalDirectories: readonly string[],
	mode: WorkerMode,
): Promise<Worker> {
	const args = ["--no-session"];
	if (mode === "inspect") {
		args.push(
			"--tools",
			"read,grep,glob,lsp",
			"--approval-mode",
			"always-ask",
			"--extension",
			INSPECT_GUARD_PATH,
		);
	} else {
		args.push("--auto-approve");
	}
	for (const directory of additionalDirectories) {
		args.push("--add-dir", directory);
	}

	const client = new RpcClient({
		command: ["omp"],
		cwd: root,
		env: { OMP_LEAF_WORKER: "1", OMP_LEAF_MODE: mode },
		args,
	});
	await client.start();
	return {
		client,
		queue: Promise.resolve(),
		root,
		mode,
		additionalDirectories,
	};
}

function getOrStartWorker(
	root: string,
	additionalDirectories: readonly string[],
	mode: WorkerMode,
): WorkerEntry {
	const key = JSON.stringify([mode, root, ...additionalDirectories]);
	const existing = workers.get(key);
	if (existing) return { key, promise: existing, reused: true };

	const promise = startWorker(root, additionalDirectories, mode);
	workers.set(key, promise);
	void promise.catch(() => {
		if (workers.get(key) === promise) workers.delete(key);
	});
	return { key, promise, reused: false };
}

async function withWorkerLock<T>(worker: Worker, operation: () => Promise<T>): Promise<T> {
	const previous = worker.queue;
	const gate = Promise.withResolvers<void>();
	worker.queue = gate.promise;
	await previous;
	try {
		return await operation();
	} finally {
		gate.resolve();
	}
}

function leafPrompt(task: string, workspaceRoot: string, worker: Worker): string {
	const visibleRoot = path.relative(workspaceRoot, worker.root) || ".";
	const visibleAdditional = worker.additionalDirectories.map((directory) =>
		path.relative(workspaceRoot, directory),
	);
	const additionalContext =
		visibleAdditional.length > 0
			? `Additional OMP workspace directories: ${visibleAdditional.join(", ")}.`
			: "Additional OMP workspace directories: none.";
	const workspaceContext = [
		`Leaf root: ${visibleRoot}`,
		"The leaf root is your process working directory and sole LSP workspace root.",
		additionalContext,
		"Use the leaf project's local configuration, language servers, package manager, and virtual environment.",
		"Use the leaf project's LSP configuration for shared import and type resolution. LSP references do not grant OMP file access outside the supplied workspace directories.",
		"Do not launch another OMP process and do not call leaf_omp.",
	];

	if (worker.mode === "inspect") {
		return [
			"You are the read-only investigator for one leaf project. The coordinator is preparing a plan.",
			...workspaceContext,
			"Use only read, grep, glob, and read-only LSP actions: diagnostics, definition, type_definition, implementation, references, hover, symbols, status, and capabilities.",
			"Never create, edit, delete, or rename files. Never call rename, rename_file, code_actions, reload, or raw LSP request.",
			"Investigate the task instead of implementing it. Return exact paths, symbols, affected callsites, diagnostics, and unresolved facts needed for a decision-complete plan.",
			`Planning task:\n${task.trim()}`,
		].join("\n\n");
	}

	return [
		"You are the implementation owner for one leaf project.",
		...workspaceContext,
		visibleAdditional.length > 0
			? "You may directly read, search, and edit the additional workspace directories."
			: "Do not read or edit outside the leaf root.",
		"Complete the task end to end. Verify behavioral changes with the narrowest relevant command or scenario.",
		"Finish with the files changed, verification performed, and any blocker.",
		`Task:\n${task.trim()}`,
	].join("\n\n");
}

async function runTurn(
	worker: Worker,
	prompt: string,
	timeoutMs: number,
	signal?: AbortSignal,
): Promise<string> {
	if (signal?.aborted) throw new Error("Leaf task was cancelled before it started");

	const turn = worker.client.promptAndWait(prompt, undefined, timeoutMs);
	if (signal) {
		let settled = false;
		const aborted = Promise.withResolvers<never>();
		const onAbort = (): void => {
			if (settled) return;
			settled = true;
			aborted.reject(new Error("Leaf task was cancelled"));
		};
		signal.addEventListener("abort", onAbort, { once: true });
		if (signal.aborted) onAbort();
		try {
			await Promise.race([turn, aborted.promise]);
		} finally {
			settled = true;
			signal.removeEventListener("abort", onAbort);
		}
	} else {
		await turn;
	}

	const result = await worker.client.getLastAssistantText();
	if (result === null || result.trim() === "") {
		throw new Error("Leaf OMP completed without an assistant response");
	}
	return result;
}

async function stopAllWorkers(): Promise<void> {
	const pending = [...workers.values()];
	workers.clear();
	await Promise.all(
		pending.map(async (workerPromise) => {
			try {
				const worker = await workerPromise;
				await worker.client.stop();
			} catch {
				// Failed startups clean up their own child process.
			}
		}),
	);
}

const factory: CustomToolFactory = (pi) => {
	const z = pi.zod;
	const isLeafWorker = process.env.OMP_LEAF_WORKER === "1";

	return {
		name: "leaf_omp",
		label: "Leaf OMP",
		strict: true,
		hidden: isLeafWorker,
		loadMode: "essential",
		description:
			"Delegate work to a persistent OMP RPC child rooted in one nested project. In parent plan mode, it automatically runs a mechanically read-only inspector with leaf-local LSP. Outside plan mode, it runs an auto-approved implementation worker. Use it when that project's cwd-scoped LSP, package-manager dependencies, or Python virtual environment must be selected. Pass additionalDirectories only when the child must directly access paths outside the leaf root. LSP import configuration does not make those paths OMP workspace roots. Calls for the same mode and root are serialized.",
		parameters: z.object({
			root: z
				.string()
				.min(1)
				.describe(
					"Existing leaf project directory relative to the coordinator workspace. It becomes the child process cwd and sole LSP workspace root.",
				),
			task: z
				.string()
				.min(1)
				.describe(
					"Complete, self-contained task. In plan mode the child investigates it without editing; outside plan mode the child implements it. Include relevant paths, constraints, expected behavior, and required verification.",
				),
			additionalDirectories: z
				.array(z.string().min(1))
				.optional()
				.describe(
					"Optional existing directories relative to the coordinator workspace. Pass only when the child must directly read, search, or edit files outside the leaf root. Omit when shared paths are needed only for LSP resolution or the task stays inside the leaf root.",
				),
			timeoutSeconds: z
				.number()
				.int()
				.min(30)
				.max(3600)
				.optional()
				.describe("Maximum child turn duration in seconds, from 30 to 3600. Defaults to 900."),
		}),

		async execute(_toolCallId, params, onUpdate, ctx, signal) {
			const currentWorkspace = ctx.sessionManager.getCwd();
			let mode: WorkerMode = "implement";
			for (const entry of ctx.sessionManager.getBranch()) {
				if (entry.type === "mode_change") {
					mode = entry.mode === "plan" ? "inspect" : "implement";
				}
			}
			let workspaceRoot: string;
			let root: string;
			let additionalDirectories: string[];
			try {
				workspaceRoot = await realpath(currentWorkspace);
				root = await canonicalDirectory(workspaceRoot, params.root, "root");
				additionalDirectories = await resolveAdditionalDirectories(
					workspaceRoot,
					root,
					params.additionalDirectories,
				);
			} catch (error) {
				return {
					content: [{ type: "text", text: error instanceof Error ? error.message : String(error) }],
					isError: true,
					details: { requestedRoot: params.root },
				};
			}

			const entry = getOrStartWorker(root, additionalDirectories, mode);
			const visibleRoot = path.relative(workspaceRoot, root) || ".";
			onUpdate?.({
				content: [
					{
						type: "text",
						text: `${entry.reused ? "Reusing" : "Starting"} leaf OMP ${mode === "inspect" ? "inspector" : "worker"} in ${visibleRoot}`,
					},
				],
				details: { root: visibleRoot, mode, reused: entry.reused },
			});

			let worker: Worker | undefined;
			try {
				const activeWorker = await entry.promise;
				worker = activeWorker;
				const timeoutMs = (params.timeoutSeconds ?? DEFAULT_TIMEOUT_SECONDS) * 1000;
				const result = await withWorkerLock(activeWorker, () =>
					runTurn(
						activeWorker,
						leafPrompt(params.task, workspaceRoot, activeWorker),
						timeoutMs,
						signal,
					),
				);
				const label = mode === "inspect" ? "inspection" : "implementation";
				return {
					content: [{ type: "text", text: `Leaf OMP ${label} (${visibleRoot}):\n\n${result}` }],
					details: {
						root: visibleRoot,
						mode,
						additionalDirectories: additionalDirectories.map(
							(directory) => path.relative(workspaceRoot, directory) || ".",
						),
						reused: entry.reused,
					},
				};
			} catch (error) {
				if (workers.get(entry.key) === entry.promise) workers.delete(entry.key);
				if (worker) await worker.client.stop();
				return {
					content: [
						{
							type: "text",
							text: `Leaf OMP failed in ${visibleRoot}: ${error instanceof Error ? error.message : String(error)}`,
						},
					],
					isError: true,
					details: { root: visibleRoot, mode, reused: entry.reused },
				};
			}
		},

		async onSession(event) {
			if (["shutdown", "switch", "branch", "tree"].includes(event.reason)) {
				await stopAllWorkers();
			}
		},
	};
};

export default factory;
