-- Treesitter: Syntax highlighting and code understanding
-- NOTE: nvim 0.11+ has treesitter highlight/indent built-in.
-- nvim-treesitter plugin now only manages parser installation.

return {
  -- Parser installation and management
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      -- Install parsers that are missing
      local langs = {
        "bash",
        "c",
        "css",
        "dockerfile",
        "go",
        "html",
        "javascript",
        "json",
        "lua",
        "luadoc",
        "luap",
        "markdown",
        "markdown_inline",
        "python",
        "query",
        "regex",
        "rust",
        "scss",
        "sql",
        "toml",
        "tsx",
        "typescript",
        "vim",
        "vimdoc",
        "xml",
        "yaml",
      }

      -- Auto-install missing parsers on startup
      local installed = require("nvim-treesitter.config").get_installed()
      local missing = vim.tbl_filter(function(lang)
        return not vim.list_contains(installed, lang)
      end, langs)

      if #missing > 0 then
        require("nvim-treesitter.install").install(missing)
      end
    end,
  },

  -- Treesitter text objects (select, move, swap)
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require("nvim-treesitter-textobjects").setup({
        select = {
          lookahead = true,
        },
        move = {
          set_jumps = true,
        },
      })

      local select = require("nvim-treesitter-textobjects.select")
      local move = require("nvim-treesitter-textobjects.move")

      -- Select text objects
      local select_maps = {
        ["af"] = "@function.outer",
        ["if"] = "@function.inner",
        ["ac"] = "@class.outer",
        ["ic"] = "@class.inner",
        ["aa"] = "@parameter.outer",
        ["ia"] = "@parameter.inner",
      }
      for keys, query in pairs(select_maps) do
        vim.keymap.set({ "x", "o" }, keys, function()
          select.select_textobject(query, "textobjects")
        end, { desc = "TS: " .. query })
      end

      -- Move to next/previous text objects
      local move_maps = {
        ["]f"] = { move.goto_next_start, "@function.outer" },
        ["]c"] = { move.goto_next_start, "@class.outer" },
        ["]F"] = { move.goto_next_end, "@function.outer" },
        ["]C"] = { move.goto_next_end, "@class.outer" },
        ["[f"] = { move.goto_previous_start, "@function.outer" },
        ["[c"] = { move.goto_previous_start, "@class.outer" },
        ["[F"] = { move.goto_previous_end, "@function.outer" },
        ["[C"] = { move.goto_previous_end, "@class.outer" },
      }
      for keys, def in pairs(move_maps) do
        vim.keymap.set({ "n", "x", "o" }, keys, function()
          def[1](def[2], "textobjects")
        end, { desc = "TS: " .. def[2] })
      end
    end,
  },
}
