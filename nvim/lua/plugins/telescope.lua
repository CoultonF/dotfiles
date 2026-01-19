-- Telescope: Fuzzy finder

return {
  {
    "nvim-telescope/telescope.nvim",
    branch = "master",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
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
      { "fd", function()
        local telescope = require("telescope")
        local builtin = require("telescope.builtin")
        local actions = require("telescope.actions")
        local action_state = require("telescope.actions.state")
        local scan = require("plenary.scandir")
        local Path = require("plenary.path")
        
        local cwd = vim.fn.getcwd()
        local dirs = {}
        
        for _, entry in ipairs(scan.scan_dir(cwd, { depth = 1, only_dirs = true })) do
          local path = Path:new(entry)
          if not path:make_relative(cwd):match("^%.") then
            table.insert(dirs, path:make_relative(cwd))
          end
        end
        
        require("telescope.pickers").new({}, {
          prompt_title = "Select Project Folder",
          finder = require("telescope.finders").new_table({ results = dirs }),
          sorter = require("telescope.config").values.generic_sorter({}),
          attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
              local selection = action_state.get_selected_entry()
              actions.close(prompt_bufnr)
              if selection then
                builtin.find_files({
                  prompt_title = "Find Files in " .. selection.value,
                  cwd = cwd .. "/" .. selection.value,
                })
              end
            end)
            return true
          end,
        }):find()
      end, desc = "Find in directory (project folder)" },

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
    config = function()
      local telescope = require("telescope")
      local themes = require("telescope.themes")
      local builtin = require("telescope.builtin")
      local actions = require("telescope.actions")
      local action_state = require("telescope.actions.state")

      telescope.setup({
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
          ["ui-select"] = themes.get_dropdown(),
        },
      })

      pcall(telescope.load_extension, "fzf")
      pcall(telescope.load_extension, "ui-select")
    end,
  },
}
