-- Treesitter: Parser management for nvim 0.12+ native tree-sitter
-- Highlighting and indentation are handled via autocmd (see config/autocmds.lua)
-- Requires tree-sitter CLI (installed via npm, see home.nix)

return {
  -- Parser installation and management
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    main = "nvim-treesitter",
    config = function()
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

      local installed = require("nvim-treesitter.config").get_installed()
      local to_install = vim.iter(langs)
        :filter(function(lang)
          return not vim.tbl_contains(installed, lang)
        end)
        :totable()

      if #to_install > 0 then
        require("nvim-treesitter").install(to_install)
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
