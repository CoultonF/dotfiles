-- Autocommands

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- Highlight on yank
augroup("YankHighlight", { clear = true })
autocmd("TextYankPost", {
  group = "YankHighlight",
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 200 })
  end,
})

-- Remove trailing whitespace on save
augroup("TrimWhitespace", { clear = true })
autocmd("BufWritePre", {
  group = "TrimWhitespace",
  pattern = "*",
  command = [[%s/\s\+$//e]],
})

-- Restore cursor position
augroup("RestoreCursor", { clear = true })
autocmd("BufReadPost", {
  group = "RestoreCursor",
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Close certain filetypes with q
augroup("CloseWithQ", { clear = true })
autocmd("FileType", {
  group = "CloseWithQ",
  pattern = {
    "help",
    "lspinfo",
    "man",
    "notify",
    "qf",
    "query",
    "spectre_panel",
    "startuptime",
    "checkhealth",
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = event.buf, silent = true })
  end,
})

-- Auto resize splits when window is resized
augroup("ResizeSplits", { clear = true })
autocmd("VimResized", {
  group = "ResizeSplits",
  callback = function()
    vim.cmd("tabdo wincmd =")
  end,
})

-- Check if file changed outside of Neovim
augroup("CheckTime", { clear = true })
autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
  group = "CheckTime",
  command = "checktime",
})

-- Set filetype for specific files
augroup("FileTypeDetect", { clear = true })
autocmd({ "BufRead", "BufNewFile" }, {
  group = "FileTypeDetect",
  pattern = { "*.mdx" },
  command = "setfiletype markdown",
})

-- Fix vim.ui.open based on environment
local function in_container()
  return os.getenv("SSH_TTY")
    or os.getenv("container")
    or os.getenv("DEVPOD_WORKSPACE_ID")
    or os.getenv("CODESPACES")
    or os.getenv("REMOTE_CONTAINERS")
    or vim.fn.filereadable("/.dockerenv") == 1
    or vim.fn.has("wsl") == 1
end

augroup("FixUiOpen", { clear = true })
autocmd("VimEnter", {
  group = "FixUiOpen",
  callback = function()
    if in_container() then
      -- In container: copy URL to clipboard via OSC52 since we can't open browser
      vim.ui.open = function(url)
        local osc52 = require("vim.ui.clipboard.osc52")
        osc52.copy("+")({ url })
        vim.notify("URL copied to clipboard: " .. url, vim.log.levels.INFO)
      end
    elseif vim.fn.has("mac") == 1 then
      -- On macOS: use 'open' instead of 'xdg-open'
      vim.ui.open = function(url)
        vim.fn.jobstart({ "open", url }, { detach = true })
      end
    end
  end,
})
