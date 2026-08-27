-- Which-key: Keybinding hints

return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      plugins = {
        marks = true,
        registers = true,
        spelling = {
          enabled = true,
          suggestions = 20,
        },
        presets = {
          operators = true,
          motions = true,
          text_objects = true,
          windows = true,
          nav = true,
          z = true,
          g = true,
        },
      },
      icons = {
        breadcrumb = "»",
        separator = "➜",
        group = "+",
      },
      win = {
        border = "rounded",
        padding = { 1, 2 },
        height = { min = 4, max = 25 },
      },
      layout = {
        width = { min = 20, max = 50 },
        spacing = 3,
      },
    },
    config = function(_, opts)
      local wk = require("which-key")
      wk.setup(opts)

      -- Register key groups
      wk.add({
        { "<leader>c", group = "Close/Code" },
        { "<leader>d", group = "Debug" },
        { "<leader>g", group = "Git" },
        { "<leader>o", group = "OMP / Tasks" },
        { "<leader>q", group = "Quickfix" },
        { "<leader>s", group = "Search" },
        { "<leader>T", group = "Terminal" },
        { "<leader>t", group = "Test" },
      })
    end,
  },
}
