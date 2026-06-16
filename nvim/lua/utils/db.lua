-- rainfrog: PostgreSQL TUI launched in a toggleterm float.
-- Replaces vim-dadbod-ui for browsing/executing; vim-dadbod core is kept only
-- for in-buffer `:DB` queries and the blink completion source (see plugins/completion.lua).
--
-- Connection URL resolution order:
--   1. $DATABASE_URL in the environment
--   2. DATABASE_URL parsed from the nearest project .env (walked upward)
--   3. none -> rainfrog falls back to its own ~/.config/rainfrog saved connections.

local M = {}

--- Walk upward from the current file/cwd for a .env and extract DATABASE_URL.
---@return string|nil
function M.url_from_dotenv()
  local start = vim.api.nvim_buf_get_name(0)
  if not start or start == "" then
    start = vim.fn.getcwd()
  end
  local envs = vim.fs.find({ ".env", ".env.local", ".env.development" }, {
    path = vim.fn.fnamemodify(start, ":p:h"),
    upward = true,
    limit = math.huge,
  })
  for _, file in ipairs(envs) do
    local ok, lines = pcall(vim.fn.readfile, file)
    if ok then
      for _, line in ipairs(lines) do
        local val = line:match("^%s*export%s+DATABASE_URL%s*=%s*(.+)$")
          or line:match("^%s*DATABASE_URL%s*=%s*(.+)$")
        if val then
          -- strip trailing whitespace/comments and surrounding quotes
          val = val:gsub("%s+$", ""):gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
          if val ~= "" then
            return val
          end
        end
      end
    end
  end
  return nil
end

local term

--- Toggle the rainfrog floating terminal, connecting to the resolved DATABASE_URL.
function M.toggle_rainfrog()
  if vim.fn.executable("rainfrog") == 0 then
    vim.notify("rainfrog not found on PATH (provision via nix, see home.nix)", vim.log.levels.ERROR)
    return
  end
  if not term then
    local url = vim.env.DATABASE_URL or M.url_from_dotenv()
    local cmd = "rainfrog"
    if url and url ~= "" then
      cmd = cmd .. " --url " .. vim.fn.shellescape(url)
    end
    term = require("toggleterm.terminal").Terminal:new({
      cmd = cmd,
      direction = "float",
      float_opts = { border = "curved" },
      hidden = true,
    })
  end
  term:toggle()
end

return M
