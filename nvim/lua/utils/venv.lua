-- Per-package virtualenv detection for Python monorepos.
-- Shared by basedpyright (before_init), neotest-python, and nvim-dap-python.

local M = {}

local function executable(path)
  return path and path ~= "" and vim.fn.executable(path) == 1
end

local function search_root(start)
  if not start or start == "" then
    start = vim.api.nvim_buf_get_name(0)
  end
  if not start or start == "" then
    start = vim.fn.getcwd()
  end

  local absolute = vim.fn.fnamemodify(start, ":p")
  if vim.fn.isdirectory(absolute) == 1 then
    return absolute
  end
  return vim.fs.dirname(absolute)
end

--- Find the best Python interpreter for the file at `start` (defaults to the
--- current buffer, then cwd). Returns an absolute path to a Python executable,
--- or nil if no project or activated environment is usable.
---@param start string|nil a file or directory path to search upward from
---@return string|nil
function M.find_python(start)
  local from = search_root(start)

  local environments = vim.fs.find({ ".venv", "venv" }, {
    path = from,
    upward = true,
    type = "directory",
    limit = math.huge,
  })
  for _, environment in ipairs(environments) do
    local py = environment .. "/bin/python"
    if executable(py) then
      return py
    end
  end

  for _, prefix in ipairs({ vim.env.VIRTUAL_ENV, vim.env.CONDA_PREFIX }) do
    local py = prefix and prefix .. "/bin/python"
    if executable(py) then
      return py
    end
  end

  return nil
end

return M
