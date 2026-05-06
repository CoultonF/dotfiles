import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { randomBytes } from "crypto";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "fs";
import { tmpdir } from "os";
import path from "path";
import { spawnSync } from "child_process";

interface NvimEvent {
	token?: string;
	type?: "tag_file" | "reference_range" | "code_block";
	path?: string;
	startLine?: number;
	endLine?: number;
	text?: string;
	lang?: string;
	modified?: boolean;
}

function shellWords(command: string): string[] {
	return command.match(/(?:[^\s"']+|"[^"]*"|'[^']*')+/g)?.map((part) => part.replace(/^(["'])(.*)\1$/, "$2")) ?? [];
}

function appendPrompt(current: string, addition: string): string {
	const trimmedAddition = addition.trim();
	if (!trimmedAddition) return current;
	if (!current.trim()) return trimmedAddition;
	return `${current.replace(/\s*$/, "")}\n\n${trimmedAddition}`;
}

function formatEvent(event: NvimEvent): string | undefined {
	if (!event.path) return undefined;

	if (event.type === "tag_file") {
		const suffix = event.modified ? " (buffer has unsaved changes)" : "";
		return `@${event.path}${suffix}`;
	}

	if (event.type === "reference_range") {
		if (!event.startLine || !event.endLine) return undefined;
		return `@${event.path}:L${event.startLine}-L${event.endLine}`;
	}

	if (event.type === "code_block") {
		if (!event.startLine || !event.endLine || event.text === undefined) return undefined;
		const lang = event.lang ?? "";
		return `@${event.path}:L${event.startLine}-L${event.endLine}\n\n\`\`\`${lang}\n${event.text.replace(/\n$/, "")}\n\`\`\``;
	}

	return undefined;
}

function readEvents(file: string, token: string): NvimEvent[] {
	let content = "";
	try {
		content = readFileSync(file, "utf-8");
	} catch {
		return [];
	}

	const events: NvimEvent[] = [];
	for (const line of content.split("\n")) {
		if (!line.trim()) continue;
		try {
			const event = JSON.parse(line) as NvimEvent;
			if (event.token === token) events.push(event);
		} catch {
			// Ignore malformed lines from a half-written append.
		}
	}
	return events;
}

const LUA_PLUGIN = String.raw`
local ref_file = vim.env.PI_NVIM_REF_FILE
local token = vim.env.PI_NVIM_TOKEN
local cwd = vim.env.PI_NVIM_CWD or vim.fn.getcwd()

local function relpath(file)
  local abs = vim.fn.fnamemodify(file, ':p')
  local root = vim.fn.fnamemodify(cwd, ':p')
  if abs:sub(1, #root) == root then
    return abs:sub(#root + 1)
  end
  return abs
end

local function lang_for(file)
  local ft = vim.bo.filetype
  if ft and ft ~= '' then return ft end
  local ext = vim.fn.fnamemodify(file, ':e')
  if ext == 'ts' then return 'typescript' end
  if ext == 'js' then return 'javascript' end
  if ext == 'tsx' then return 'tsx' end
  if ext == 'jsx' then return 'jsx' end
  if ext == 'py' then return 'python' end
  if ext == 'rs' then return 'rust' end
  if ext == 'go' then return 'go' end
  if ext == 'lua' then return 'lua' end
  if ext == 'nix' then return 'nix' end
  if ext == 'md' then return 'markdown' end
  return ext
end

local function json_encode(value)
  if vim.json and vim.json.encode then return vim.json.encode(value) end
  return vim.fn.json_encode(value)
end

local function emit(event)
  if not ref_file or ref_file == '' then
    vim.notify('PI_NVIM_REF_FILE is not set', vim.log.levels.ERROR)
    return
  end
  event.token = token
  vim.fn.writefile({ json_encode(event) }, ref_file, 'a')
  vim.notify('Added Pi reference: ' .. (event.path or ''), vim.log.levels.INFO)
end

local function current_file()
  local file = vim.api.nvim_buf_get_name(0)
  if file == '' then
    vim.notify('Current buffer has no file', vim.log.levels.WARN)
    return nil
  end
  return file
end

function _G.pi_nvim_ref_file()
  local file = current_file()
  if not file then return end
  emit({ type = 'tag_file', path = relpath(file), modified = vim.bo.modified })
end

local function selected_lines()
  local start_line = vim.fn.line("'<")
  local end_line = vim.fn.line("'>")
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  return start_line, end_line, table.concat(lines, '\n')
end

function _G.pi_nvim_ref_range(include_code)
  local file = current_file()
  if not file then return end
  local start_line, end_line, text = selected_lines()
  emit({
    type = include_code and 'code_block' or 'reference_range',
    path = relpath(file),
    startLine = start_line,
    endLine = end_line,
    text = text,
    lang = lang_for(file),
    modified = vim.bo.modified,
  })
end

vim.keymap.set('n', '<leader>af', _G.pi_nvim_ref_file, { desc = 'Pi: tag current file' })
vim.keymap.set('v', '<leader>ar', function() _G.pi_nvim_ref_range(false) end, { desc = 'Pi: reference selected range' })
vim.keymap.set('v', '<leader>aR', function() _G.pi_nvim_ref_range(true) end, { desc = 'Pi: paste selected code block' })
vim.api.nvim_create_user_command('PiTagFile', _G.pi_nvim_ref_file, {})
vim.api.nvim_create_user_command('PiRefRange', function(opts) _G.pi_nvim_ref_range(opts.bang) end, { bang = true, range = true })
`;

async function openNvim(ctx: ExtensionContext): Promise<void> {
	if (!ctx.hasUI) {
		ctx.ui.notify("/nvim-ref is only available in interactive mode", "error");
		return;
	}

	const dir = mkdtempSync(path.join(tmpdir(), "pi-nvim-ref-"));
	const eventFile = path.join(dir, "events.jsonl");
	const pluginFile = path.join(dir, "pi-nvim-ref.lua");
	const token = randomBytes(16).toString("hex");
	writeFileSync(eventFile, "", "utf-8");
	writeFileSync(pluginFile, LUA_PLUGIN, "utf-8");

	const editorCommand = process.env.PI_NVIM_CMD || process.env.NVIM || "nvim";
	const [cmd, ...cmdArgs] = shellWords(editorCommand);
	if (!cmd) {
		ctx.ui.notify("PI_NVIM_CMD is empty", "error");
		rmSync(dir, { recursive: true, force: true });
		return;
	}

	const wasRaw = Boolean(process.stdin.isTTY && process.stdin.isRaw);
	try {
		try {
			ctx.ui.notify("Opening Neovim. Use <leader>af, visual <leader>ar, or visual <leader>aR; quit Neovim to return to Pi.");
			if (process.stdin.isTTY) process.stdin.setRawMode(false);
			process.stdout.write("\x1b[2J\x1b[H");

			const result = spawnSync(cmd, [...cmdArgs, ".", "-c", `lua dofile(${JSON.stringify(pluginFile)})`], {
				cwd: ctx.cwd,
				stdio: "inherit",
				env: {
					...process.env,
					PI_NVIM_REF_FILE: eventFile,
					PI_NVIM_TOKEN: token,
					PI_NVIM_CWD: ctx.cwd,
				},
				shell: process.platform === "win32",
			});

			if (result.error) {
				ctx.ui.notify(`Failed to launch Neovim: ${result.error.message}`, "error");
				return;
			}
			if (result.status !== 0) {
				ctx.ui.notify(`Neovim exited with status ${result.status}; keeping prompt unchanged`, "warning");
				return;
			}
		} finally {
			if (process.stdin.isTTY) process.stdin.setRawMode(wasRaw);
		}

		const additions = readEvents(eventFile, token).map(formatEvent).filter((text): text is string => Boolean(text));
		if (additions.length > 0) {
			ctx.ui.setEditorText(appendPrompt(ctx.ui.getEditorText(), additions.join("\n\n")));
			ctx.ui.notify(`Added ${additions.length} Neovim reference${additions.length === 1 ? "" : "s"}`, "info");
		} else {
			ctx.ui.notify("No Neovim references added", "info");
		}
	} finally {
		try {
			rmSync(dir, { recursive: true, force: true });
		} catch {
			// Best-effort cleanup.
		}
	}
}

export default function nvimRef(pi: ExtensionAPI): void {
	pi.registerCommand("nvim-ref", {
		description: "Open Neovim in the current project and append file/code references to the prompt",
		handler: async (_args, ctx) => openNvim(ctx),
	});

	pi.registerCommand("nvim", {
		description: "Alias for /nvim-ref",
		handler: async (_args, ctx) => openNvim(ctx),
	});
}
