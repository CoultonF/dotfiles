-- OSC 52 clipboard for remote/container environments
-- This makes the system clipboard work over SSH/containers

-- Auto-detect container/remote environments
local function in_container()
  return os.getenv("SSH_TTY")
    or os.getenv("container")
    or os.getenv("DEVPOD_WORKSPACE_ID")
    or os.getenv("CODESPACES")
    or os.getenv("REMOTE_CONTAINERS")
    or vim.fn.filereadable("/.dockerenv") == 1
    or vim.fn.has("wsl") == 1
end

-- Set up OSC52 as the clipboard provider (works with Neovim 0.10+)
if in_container() then
  vim.g.clipboard = {
    name = "OSC 52",
    copy = {
      ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
      ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
    },
    paste = {
      ["+"] = require("vim.ui.clipboard.osc52").paste("+"),
      ["*"] = require("vim.ui.clipboard.osc52").paste("*"),
    },
  }
end

return {}
