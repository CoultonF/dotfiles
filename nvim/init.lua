-- Neovim Configuration
-- Bootstrap lazy.nvim and load config modules

-- Set leader key early (before lazy)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Load configuration modules
require("config.options")
require("config.lazy")
require("config.keymaps")
require("config.autocmds")
