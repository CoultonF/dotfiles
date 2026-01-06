-- Telescope: Fuzzy finder

return {
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
        cond = function()
          return vim.fn.executable("make") == 1
        end,
      },
      "nvim-telescope/telescope-ui-select.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    cmd = "Telescope",
    keys = {
      -- File finding (like VS Code ff, leader leader)
      { "ff", "<cmd>Telescope find_files<CR>", desc = "Find files" },
      { "<leader><leader>", "<cmd>Telescope find_files<CR>", desc = "Find files" },

      -- Buffer switching (like VS Code leader ,)
      { "<leader>,", "<cmd>Telescope buffers<CR>", desc = "Switch buffer" },

      -- Grep (like VS Code gf)
      { "gf", "<cmd>Telescope live_grep<CR>", desc = "Live grep" },
      { "<leader>sg", "<cmd>Telescope live_grep<CR>", desc = "Search grep" },
      { "<leader>sw", "<cmd>Telescope grep_string<CR>", desc = "Search word under cursor" },

      -- Search
      { "<leader>sf", "<cmd>Telescope find_files<CR>", desc = "Search files" },
      { "<leader>sh", "<cmd>Telescope help_tags<CR>", desc = "Search help" },
      { "<leader>sk", "<cmd>Telescope keymaps<CR>", desc = "Search keymaps" },
      { "<leader>sr", "<cmd>Telescope resume<CR>", desc = "Search resume" },
      { "<leader>s.", "<cmd>Telescope oldfiles<CR>", desc = "Recent files" },
      { "<leader>/", "<cmd>Telescope current_buffer_fuzzy_find<CR>", desc = "Search in buffer" },

      -- Git
      { "<leader>gc", "<cmd>Telescope git_branches<CR>", desc = "Git branches (checkout)" },
      { "<leader>gD", "<cmd>Telescope git_commits<CR>", desc = "Git commits (file history)" },

      -- LSP
      { "<leader>ss", "<cmd>Telescope lsp_document_symbols<CR>", desc = "Document symbols" },
      { "<leader>sS", "<cmd>Telescope lsp_workspace_symbols<CR>", desc = "Workspace symbols" },

      -- Diagnostics
      { "<leader>sd", "<cmd>Telescope diagnostics bufnr=0<CR>", desc = "Buffer diagnostics" },
      { "<leader>sD", "<cmd>Telescope diagnostics<CR>", desc = "Workspace diagnostics" },
    },
    opts = {
      defaults = {
        prompt_prefix = " ",
        selection_caret = " ",
        path_display = { "truncate" },
        sorting_strategy = "ascending",
        layout_config = {
          horizontal = {
            prompt_position = "top",
            preview_width = 0.55,
          },
          vertical = {
            mirror = false,
          },
          width = 0.87,
          height = 0.80,
          preview_cutoff = 120,
        },
        mappings = {
          i = {
            ["<C-j>"] = "move_selection_next",
            ["<C-k>"] = "move_selection_previous",
            ["<C-q>"] = "close",
            ["<Esc>"] = "close",
          },
          n = {
            ["q"] = "close",
          },
        },
      },
      pickers = {
        find_files = {
          hidden = true,
          file_ignore_patterns = { ".git/", "node_modules/", ".venv/", "__pycache__/" },
        },
        live_grep = {
          additional_args = function()
            return { "--hidden" }
          end,
        },
      },
      extensions = {
        ["ui-select"] = {
          require("telescope.themes").get_dropdown(),
        },
      },
    },
    config = function(_, opts)
      require("telescope").setup(opts)
      pcall(require("telescope").load_extension, "fzf")
      pcall(require("telescope").load_extension, "ui-select")
    end,
  },
}
