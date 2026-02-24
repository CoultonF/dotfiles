-- Colorscheme: Catppuccin Mocha (matches VS Code theme)

return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    lazy = false,
    opts = {
      flavour = "mocha",
      background = {
        light = "latte",
        dark = "mocha",
      },
      transparent_background = false,
      term_colors = true,
      styles = {
        comments = { "italic" },
        conditionals = { "italic" },
        keywords = { "italic" },
        properties = { "italic" },
        types = { "italic" },
      },
      custom_highlights = function(colors)
        return {
          -- === Shared / general ===
          -- Decorators: yellow + italic
          ["@attribute"] = { fg = colors.yellow, style = { "italic" } },
          ["@attribute.builtin"] = { fg = colors.yellow, style = { "italic" } },

          -- === Python ===
          -- self/cls: italic red
          ["@variable.builtin.python"] = { fg = colors.red, style = { "italic" } },
          -- Parameters keep maroon color at usage sites via Pyright semantic tokens
          ["@lsp.type.parameter.python"] = { fg = colors.maroon, style = { "italic" } },
          -- Modules/namespaces
          ["@lsp.type.namespace.python"] = { fg = colors.yellow, style = { "italic" } },
          -- Decorator from LSP
          ["@lsp.type.decorator.python"] = { fg = colors.yellow, style = { "italic" } },

          -- === TSX / TypeScript ===
          -- Parameters at usage sites via ts_ls semantic tokens
          ["@lsp.type.parameter.typescript"] = { fg = colors.maroon, style = { "italic" } },
          ["@lsp.type.parameter.typescriptreact"] = { fg = colors.maroon, style = { "italic" } },
          -- Interfaces: italic to distinguish from classes
          ["@lsp.type.interface.typescript"] = { fg = colors.yellow, style = { "italic" } },
          ["@lsp.type.interface.typescriptreact"] = { fg = colors.yellow, style = { "italic" } },
          -- Type parameters (generics <T, K>)
          ["@lsp.type.typeParameter.typescript"] = { fg = colors.yellow, style = { "italic" } },
          ["@lsp.type.typeParameter.typescriptreact"] = { fg = colors.yellow, style = { "italic" } },
          -- Enum members
          ["@lsp.type.enumMember.typescript"] = { fg = colors.teal },
          ["@lsp.type.enumMember.typescriptreact"] = { fg = colors.teal },
        }
      end,
      integrations = {
        cmp = true,
        gitsigns = true,
        harpoon = true,
        indent_blankline = { enabled = true },
        lsp_trouble = true,
        mason = true,
        native_lsp = {
          enabled = true,
          underlines = {
            errors = { "undercurl" },
            hints = { "undercurl" },
            warnings = { "undercurl" },
            information = { "undercurl" },
          },
        },
        notify = true,
        nvimtree = true,
        telescope = { enabled = true },
        treesitter = true,
        which_key = true,
      },
    },
    config = function(_, opts)
      require("catppuccin").setup(opts)
      vim.cmd.colorscheme("catppuccin")
    end,
  },
}
