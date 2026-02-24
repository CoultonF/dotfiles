-- Neo-tree: File tree sidebar for project context

local function toggle_explorer()
  local neo_tree_open = false
  local oil_open = false

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local ft = vim.bo[buf].filetype
    if ft == "neo-tree" then neo_tree_open = true end
    if ft == "oil" then oil_open = true end
  end

  if not neo_tree_open and not oil_open then
    vim.cmd("Neotree show")
    require("oil").open_float()
  elseif neo_tree_open and not oil_open then
    require("oil").open_float()
  elseif not neo_tree_open and oil_open then
    vim.cmd("Neotree show")
  else
    require("oil").close()
  end
end

return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
      "stevearc/oil.nvim",
    },
    cmd = { "Neotree" },
    keys = {
      { "<leader>x", toggle_explorer, desc = "Toggle file explorer" },
      { "<leader>ge", "<cmd>Neotree git_status<CR>", desc = "Git explorer" },
    },
    init = function()
      vim.api.nvim_create_autocmd("VimEnter", {
        group = vim.api.nvim_create_augroup("NeoTreeAutoOpen", { clear = true }),
        callback = function()
          if vim.fn.argc() == 1 and vim.fn.isdirectory(vim.fn.argv(0)) == 1 then
            vim.defer_fn(function()
              vim.cmd("Neotree show")
              require("oil").open_float()
            end, 50)
          end
        end,
      })
    end,
    opts = {
      filesystem = {
        filtered_items = {
          hide_dotfiles = false,
          hide_gitignored = true,
          hide_by_name = { "node_modules", "__pycache__", ".git" },
        },
        follow_current_file = { enabled = true },
        use_libuv_file_watcher = true,
      },
      window = {
        width = 35,
      },
      default_component_configs = {
        git_status = {
          symbols = {
            added = "+",
            modified = "~",
            deleted = "x",
            renamed = "r",
            untracked = "?",
            ignored = "◌",
            unstaged = "○",
            staged = "●",
            conflict = "!",
          },
        },
      },
    },
  },
}
