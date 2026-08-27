-- Telescope: Fuzzy finder

local file_ignore_patterns = {
  "%.git/",
  "node_modules/",
  "%.venv/",
  "routeTree%.gen%.ts$",
  "web%-api%.gen%.d%.ts$",
  "openapi%.json$",
  "tsconfig.*%.tsbuildinfo$",
  "%.tanstack/",
  "out/",
  "test%-results/",
  "playwright%-report/",
}

local live_grep_ignored_globs = {
  "!**/.git/**",
  "!**/node_modules/**",
  "!**/.venv/**",
  "!**/routeTree.gen.ts",
  "!**/web-api.gen.d.ts",
  "!**/openapi.json",
  "!**/tsconfig.*.tsbuildinfo",
  "!**/.tanstack/**",
  "!**/out/**",
  "!**/test-results/**",
  "!**/playwright-report/**",
}

local function in_git_worktree(cwd)
  local output = vim.fn.system({ "git", "-C", cwd, "rev-parse", "--is-inside-work-tree" })
  return vim.v.shell_error == 0 and vim.trim(output) == "true"
end

local function find_project_files(opts)
  local builtin = require("telescope.builtin")
  opts = vim.tbl_deep_extend("force", {
    hidden = true,
    file_ignore_patterns = file_ignore_patterns,
  }, opts or {})

  local cwd = opts.cwd or vim.fn.getcwd()
  if in_git_worktree(cwd) then
    -- The explicit pathspec keeps nested pickers relative to their source
    -- directory instead of returning repository-root paths.
    opts.use_git_root = false
    opts.git_command = {
      "git",
      "-c",
      "core.quotepath=false",
      "ls-files",
      "--exclude-standard",
      "--cached",
      "--others",
      "--",
      ".",
    }
    opts.show_untracked = false
    builtin.git_files(opts)
  else
    builtin.find_files(opts)
  end
end

local function project_folder_picker()
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local finders = require("telescope.finders")
  local pickers = require("telescope.pickers")
  local conf = require("telescope.config").values
  local Path = require("plenary.path")
  local scan = require("plenary.scandir")

  local cwd = vim.fn.getcwd()
  local excluded = {
    "node_modules",
    "worktrees",
    "tmp",
    "artifacts",
    "_artifacts",
    "playwright-results",
  }
  local dirs = {}

  for _, entry in ipairs(scan.scan_dir(cwd, { depth = 1, only_dirs = true })) do
    local relative = Path:new(entry):make_relative(cwd)
    if not relative:match("^%.") and not vim.tbl_contains(excluded, relative) then
      table.insert(dirs, relative)
    end
  end
  table.sort(dirs)

  pickers.new({}, {
    prompt_title = "Select Project Folder",
    finder = finders.new_table({ results = dirs }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if selection then
          find_project_files({
            prompt_title = "Find Files in " .. selection.value,
            cwd = vim.fs.joinpath(cwd, selection.value),
          })
        end
      end)
      return true
    end,
  }):find()
end

return {
  {
    "nvim-telescope/telescope.nvim",
    branch = "master",
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
      { "<leader><leader>", find_project_files, desc = "Find files" },
      { "<leader>,", "<cmd>Telescope buffers<CR>", desc = "Switch buffer" },

      -- Grep
      { "<leader>sg", "<cmd>Telescope live_grep<CR>", desc = "Search grep" },
      { "<leader>sw", "<cmd>Telescope grep_string<CR>", desc = "Search word under cursor" },

      -- Search
      { "<leader>sf", find_project_files, desc = "Search files" },
      { "<leader>sP", project_folder_picker, desc = "Search project folder" },
      { "<leader>sh", "<cmd>Telescope help_tags<CR>", desc = "Search help" },
      { "<leader>sk", "<cmd>Telescope keymaps<CR>", desc = "Search keymaps" },
      { "<leader>sr", "<cmd>Telescope resume<CR>", desc = "Search resume" },
      { "<leader>s.", "<cmd>Telescope oldfiles<CR>", desc = "Recent files" },
      { "<leader>/", "<cmd>Telescope current_buffer_fuzzy_find<CR>", desc = "Search in buffer" },

      -- Git
      { "<leader>gc", "<cmd>Telescope git_branches<CR>", desc = "Git branches (checkout)" },
      { "<leader>gC", "<cmd>Telescope git_commits<CR>", desc = "Git commits (repository)" },

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

      telescope.setup({
        defaults = {
          prompt_prefix = " ",
          selection_caret = " ",
          path_display = { "truncate" },
          file_ignore_patterns = file_ignore_patterns,
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
              -- Readline-style input editing
              ["<C-a>"] = { "<Home>", type = "command" },
              ["<C-e>"] = { "<End>", type = "command" },
              ["<C-b>"] = { "<Left>", type = "command" },
              ["<C-f>"] = { "<Right>", type = "command" },
              ["<C-w>"] = { "<C-S-w>", type = "command" },
              ["<C-u>"] = { "<C-u>", type = "command" },
            },
            n = {
              ["q"] = "close",
            },
          },
        },
        pickers = {
          find_files = {
            hidden = true,
          },
          live_grep = {
            additional_args = function()
              local args = { "--hidden" }
              for _, glob in ipairs(live_grep_ignored_globs) do
                table.insert(args, "--glob")
                table.insert(args, glob)
              end
              return args
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
