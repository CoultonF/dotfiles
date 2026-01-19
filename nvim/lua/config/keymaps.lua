-- Keymaps
-- Ported from VS Code vim configuration

local map = vim.keymap.set

-- Better up/down with line wrapping
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })

-- Move 5 lines at a time with K/J (like VS Code config)
map("n", "K", "5kzz", { desc = "Move up 5 lines and center" })
map("n", "J", "5jzz", { desc = "Move down 5 lines and center" })

-- Visual mode: move lines up/down
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })

-- Keep cursor centered when scrolling
map("n", "<C-d>", "<C-d>zz", { desc = "Scroll down and center" })
map("n", "<C-u>", "<C-u>zz", { desc = "Scroll up and center" })

-- Keep cursor centered when searching
map("n", "n", "nzzzv", { desc = "Next search result centered" })
map("n", "N", "Nzzzv", { desc = "Prev search result centered" })
map("n", "*", "*zzzv", { desc = "Search word under cursor centered" })



-- Better paste (don't yank replaced text)
map("x", "p", [["_dP]], { desc = "Paste without yanking" })

-- System clipboard with leader
map({ "n", "v" }, "<leader>y", [["+y]], { desc = "Yank to system clipboard" })
map("n", "<leader>Y", [["+Y]], { desc = "Yank line to system clipboard" })
map({ "n", "v" }, "<leader>p", [["+p]], { desc = "Paste from system clipboard" })
map({ "n", "v" }, "<leader>P", [["+P]], { desc = "Paste before from system clipboard" })

-- Delete to void register
map({ "n", "v" }, "<leader>d", [["_d]], { desc = "Delete to void register" })

-- Window navigation with Ctrl+hjkl (navigate visible splits)
map("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Go to lower window" })
map("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })
map("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })

-- Buffer navigation (cycle through buffer list)
map("n", "<leader>bn", "<cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "<leader>bp", "<cmd>bprevious<CR>", { desc = "Previous buffer" })

-- Close buffer
map("n", "<C-q>", "<cmd>bd<CR>", { desc = "Close buffer" })
map("n", "<leader>cc", "<cmd>bd<CR>", { desc = "Close buffer" })
map("n", "<leader>cD", "<cmd>%bd<CR>", { desc = "Close all buffers" })

-- Window splits (like VS Code)
map("n", "<leader>cL", "<cmd>vsplit<CR>", { desc = "Split right" })
map("n", "<leader>cJ", "<cmd>split<CR>", { desc = "Split down" })

-- Move editor to group (like VS Code)
map("n", "<leader>l", "<cmd>wincmd L<CR>", { desc = "Move to right group" })
map("n", "<leader>h", "<cmd>wincmd H<CR>", { desc = "Move to left group" })

-- Resize windows
map("n", "<C-Up>", "<cmd>resize +2<CR>", { desc = "Increase window height" })
map("n", "<C-Down>", "<cmd>resize -2<CR>", { desc = "Decrease window height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<CR>", { desc = "Decrease window width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<CR>", { desc = "Increase window width" })

-- Clear search highlight
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

-- Folding (like VS Code leader f/F)
map("n", "<leader>f", "za", { desc = "Toggle fold" })
map("n", "<leader>F", "zA", { desc = "Toggle all folds" })

-- Join lines (like VS Code leader j)
map("n", "<leader>j", "J", { desc = "Join lines" })

-- Search and replace word under cursor (like VS Code leader s)
map("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], { desc = "Search/replace word" })

-- Navigate jumplist (like VS Code Ctrl+O/I)
map("n", "<C-o>", "<C-o>", { desc = "Jump back" })
map("n", "<C-i>", "<C-i>", { desc = "Jump forward" })

-- Better indenting (stay in visual mode)
map("v", "<", "<gv", { desc = "Indent left" })
map("v", ">", ">gv", { desc = "Indent right" })

-- Quickfix navigation
map("n", "<leader>qn", "<cmd>cnext<CR>", { desc = "Next quickfix" })
map("n", "<leader>qp", "<cmd>cprev<CR>", { desc = "Prev quickfix" })
map("n", "<leader>qo", "<cmd>copen<CR>", { desc = "Open quickfix" })
map("n", "<leader>qc", "<cmd>cclose<CR>", { desc = "Close quickfix" })

-- Navigate to breakpoints (like VS Code leader o/i)
map("n", "<leader>o", function()
  require("dap").step_over()
end, { desc = "Debug: Step over" })
map("n", "<leader>i", function()
  require("dap").step_into()
end, { desc = "Debug: Step into" })

-- Diagnostic navigation
map("n", "[d", vim.diagnostic.goto_prev, { desc = "Go to previous diagnostic" })
map("n", "]d", vim.diagnostic.goto_next, { desc = "Go to next diagnostic" })
map("n", "<leader>e", vim.diagnostic.open_float, { desc = "Show diagnostic message" })
