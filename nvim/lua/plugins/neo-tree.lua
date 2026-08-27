-- Neo-tree: File tree sidebar for project context

return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    cmd = { "Neotree" },
    keys = {
      { "<leader>x", "<cmd>Neotree toggle<CR>", desc = "Toggle file explorer" },
      { "<leader>gE", "<cmd>Neotree git_status<CR>", desc = "Git explorer" },
    },
    opts = {
      filesystem = {
        filtered_items = {
          hide_dotfiles = false,
          hide_gitignored = true,
          never_show = { ".git", "__pycache__" },
        },
        follow_current_file = { enabled = false },
        use_libuv_file_watcher = false,
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
