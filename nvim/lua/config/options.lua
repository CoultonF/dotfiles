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

-- Clipboard (OSC 52 plugin handles remote clipboard, see plugins/osc52.lua)
opt.clipboard = "unnamedplus"

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
