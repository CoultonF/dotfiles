-- Per-package virtualenv detection for Python monorepos.
-- Walks upward from the current file looking for a usable venv python,
-- preferring an already-active environment. Shared by basedpyright (before_init),
-- neotest-python, and nvim-dap (dap-python).

local M = {}

local function executable(path)
  return path and path ~= "" and vim.fn.executable(path) == 1
end

--- Find the best Python interpreter for the file at `start` (defaults to the
--- current buffer, then cwd). Returns an absolute path to a python executable,
--- or nil if none is found (callers fall back to "python").
---@param start string|nil a file path to search upward from
---@return string|nil
function M.find_python(start)
  -- 1) An explicitly activated environment always wins.
  local active = vim.env.VIRTUAL_ENV or vim.env.CONDA_PREFIX
  if active then
    local py = active .. "/bin/python"
    if executable(py) then
      return py
    end
  end

  -- 2) Walk upward from the file for a project marker carrying a local venv.
  if not start or start == "" then
    start = vim.api.nvim_buf_get_name(0)
  end
  if not start or start == "" then
    start = vim.fn.getcwd()
  end
  local from = vim.fn.fnamemodify(start, ":p:h")

  local markers = vim.fs.find({ ".venv", "venv", "pyproject.toml", "setup.cfg", "Pipfile" }, {
    path = from,
    upward = true,
    limit = math.huge,
  })
  for _, marker in ipairs(markers) do
    local dir = vim.fn.fnamemodify(marker, ":h")
    for _, name in ipairs({ ".venv", "venv" }) do
      local py = dir .. "/" .. name .. "/bin/python"
      if executable(py) then
        return py
      end
    end
  end

  return nil
end

return M
