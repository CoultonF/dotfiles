-- OMP ("oh my pi") integration: send a selection or file + prompt to the omp CLI.
local M = {}

local uv = vim.uv or vim.loop

local function notify(msg, level)
  vim.notify("omp: " .. msg, level or vim.log.levels.INFO)
end

-- git toplevel, else cwd
local function project_root()
  local out = vim.fn.systemlist({ "git", "rev-parse", "--show-toplevel" })
  if vim.v.shell_error == 0 and out[1] and out[1] ~= "" then
    return out[1]
  end
  return vim.fn.getcwd()
end

-- path of bufnr's file relative to root, or nil if outside root / nameless
local function relative_path(bufnr, root)
  local abs = vim.api.nvim_buf_get_name(bufnr)
  if abs == "" then
    return nil
  end
  abs = vim.fn.fnamemodify(abs, ":p")
  root = vim.fn.fnamemodify(root, ":p"):gsub("/$", "")
  if abs:sub(1, #root + 1) == root .. "/" then
    return abs:sub(#root + 2)
  end
  return nil
end

-- resolve the omp working dir + file ref for bufnr; nil if buffer has no file
local function resolve_target(bufnr)
  local abs = vim.api.nvim_buf_get_name(bufnr)
  if abs == "" then
    return nil
  end
  abs = vim.fn.fnamemodify(abs, ":p")
  local root = project_root()
  local rel = relative_path(bufnr, root)
  if rel then
    return { root = root, ref = rel }
  end
  -- file outside the project root: scope omp to the file's directory
  notify("file is outside the project root; using its directory", vim.log.levels.WARN)
  return { root = vim.fn.fnamemodify(abs, ":h"), ref = abs }
end

-- capture the current visual selection's line range; must run while in visual mode
local function capture_visual()
  local mode = vim.fn.mode()
  if not mode:match("^[vV\22]") then -- \22 = CTRL-V (blockwise)
    return nil
  end
  local p1 = vim.fn.getpos("v") -- selection anchor
  local p2 = vim.fn.getpos(".") -- cursor
  local lines = vim.fn.getregion(p1, p2, { type = mode })
  if vim.tbl_isempty(lines) then
    return nil
  end
  return { first = math.min(p1[2], p2[2]), last = math.max(p1[2], p2[2]) }
end

-- omp wants the file as its own @-arg and the instruction as a separate arg
-- (`omp @file.ts "do x"`). Returns { "@ref", "instruction" }, folding any line
-- range into the instruction text since omp @-mentions attach the whole file.
local function build_message(ref, range, instruction)
  local at = "@" .. ref
  if range then
    return { at, string.format("lines %d-%d: %s", range.first, range.last, instruction) }
  end
  return { at, instruction }
end

-- omp reads from disk, so flush the buffer first; false if the buffer has no file
local function ensure_saved(bufnr)
  if vim.api.nvim_buf_get_name(bufnr) == "" then
    notify("buffer has no file - save it first", vim.log.levels.ERROR)
    return false
  end
  if vim.bo[bufnr].modified then
    vim.api.nvim_buf_call(bufnr, function()
      vim.cmd("silent! write")
    end)
  end
  return true
end

-- "omp" if on PATH, else the bun global, else nil
local function omp_bin()
  if vim.fn.executable("omp") == 1 then
    return "omp"
  end
  local fallback = vim.fn.expand("~/.bun/bin/omp")
  if uv.fs_stat(fallback) then
    return fallback
  end
  notify("not found on PATH or ~/.bun/bin", vim.log.levels.ERROR)
  return nil
end

-- reload the source buffer after omp may have edited the file on disk
local function reload_buffer(bufnr)
  vim.cmd("checktime")
  if vim.api.nvim_buf_is_valid(bufnr) and not vim.bo[bufnr].modified then
    vim.api.nvim_buf_call(bufnr, function()
      vim.cmd("silent! edit")
    end)
  end
end

-- run omp interactively in a toggleterm float; reload the buffer on exit.
-- omp without `-p` stays in an interactive REPL after the initial prompt, so the
-- user can ask follow-ups in the terminal. `flags` are extra omp flags, e.g.
-- {"--auto-approve"} to edit in place without per-tool approval prompts.
local function launch_float(root, message, src_bufnr, flags)
  local bin = omp_bin()
  if not bin then
    return
  end
  pcall(function() -- toggleterm is lazy-loaded on keys; ensure it's on rtp first
    require("lazy").load({ plugins = { "toggleterm.nvim" } })
  end)
  local ok, terminal = pcall(require, "toggleterm.terminal")
  if not ok then
    notify("toggleterm not available", vim.log.levels.ERROR)
    return
  end

  local parts = { vim.fn.shellescape(bin) }
  for _, flag in ipairs(flags or {}) do
    table.insert(parts, flag)
  end
  table.insert(parts, "--cwd=" .. vim.fn.shellescape(root))
  table.insert(parts, vim.fn.shellescape(message[1])) -- @file mention
  table.insert(parts, vim.fn.shellescape(message[2])) -- instruction
  local cmd = table.concat(parts, " ")

  local term = terminal.Terminal:new({
    cmd = cmd,
    dir = root,
    direction = "float",
    close_on_exit = false, -- keep omp's final summary visible
    float_opts = { border = "curved" },
    on_exit = function()
      vim.schedule(function()
        reload_buffer(src_bufnr)
        notify("finished")
      end)
    end,
  })
  term:toggle()
end

-- prompt for an instruction, then run `action(target.root, message, bufnr)`
local function with_instruction(bufnr, range, prompt, action)
  local target = resolve_target(bufnr)
  if not target then
    notify("buffer has no file - save it first", vim.log.levels.ERROR)
    return
  end
  if not ensure_saved(bufnr) then
    return
  end
  vim.ui.input({ prompt = prompt }, function(instruction)
    if not instruction or instruction:gsub("%s", "") == "" then
      notify("cancelled")
      return
    end
    action(target.root, build_message(target.ref, range, instruction), bufnr)
  end)
end

-- act on the current visual selection (edit in place via float)
function M.on_selection()
  local range = capture_visual()
  if not range then
    notify("no visual selection", vim.log.levels.WARN)
    return
  end
  local bufnr = vim.api.nvim_get_current_buf()
  with_instruction(bufnr, range, "omp instruction: ", function(root, message, b)
    launch_float(root, message, b, { "--auto-approve" })
  end)
end

-- act on the whole current file (edit in place via float)
function M.on_file()
  local bufnr = vim.api.nvim_get_current_buf()
  with_instruction(bufnr, nil, "omp instruction (whole file): ", function(root, message, b)
    launch_float(root, message, b, { "--auto-approve" })
  end)
end

return M
