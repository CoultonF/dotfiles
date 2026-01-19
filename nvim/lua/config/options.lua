-- Neovim Options

local opt = vim.opt

-- Line numbers
opt.number = true
opt.relativenumber = true

-- Tabs & Indentation
opt.tabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.autoindent = true
opt.smartindent = true

-- Line wrapping
opt.wrap = false

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

-- Cursor
opt.cursorline = true

-- Appearance
opt.termguicolors = true
opt.background = "dark"
opt.signcolumn = "yes"

-- Backspace
opt.backspace = "indent,eol,start"

-- Clipboard (system clipboard with OSC 52 support for containers/SSH)
opt.clipboard = "unnamedplus"

-- Use OSC 52 for clipboard in containers/SSH (works with most modern terminals)
-- Detect container environments: DevPod, Docker, K8s, Codespaces, SSH, WSL
local in_container = os.getenv("SSH_TTY")
  or os.getenv("container")
  or os.getenv("DEVPOD_WORKSPACE_ID")
  or os.getenv("CODESPACES")
  or os.getenv("REMOTE_CONTAINERS")
  or vim.fn.filereadable("/.dockerenv") == 1
  or vim.fn.has("wsl") == 1

if in_container then
  local osc52 = require("vim.ui.clipboard.osc52")
  vim.g.clipboard = {
    name = "OSC 52",
    copy = {
      ["+"] = osc52.copy("+"),
      ["*"] = osc52.copy("*"),
    },
    paste = {
      ["+"] = osc52.paste("+"),
      ["*"] = osc52.paste("*"),
    },
  }
end

-- Split windows
opt.splitright = true
opt.splitbelow = true

-- Consider - as part of word
opt.iskeyword:append("-")

-- Disable mouse (vim purist mode)
-- opt.mouse = ""

-- Enable mouse (for scrolling, selection)
opt.mouse = "a"

-- Decrease update time
opt.updatetime = 250
opt.timeoutlen = 300

-- Better completion experience
opt.completeopt = "menuone,noselect"

-- Undo persistence
opt.undofile = true
opt.undolevels = 10000

-- Scroll offset
opt.scrolloff = 8
opt.sidescrolloff = 8

-- Fold settings (using treesitter)
opt.foldmethod = "expr"
opt.foldexpr = "nvim_treesitter#foldexpr()"
opt.foldenable = false
opt.foldlevel = 99

-- Disable swap files
opt.swapfile = false
opt.backup = false

-- Session options
opt.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"
