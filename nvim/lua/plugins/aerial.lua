-- aerial.nvim: persistent symbol outline for navigating large files
-- (TS/TSX components, Python modules, SQL). Complements Trouble symbols,
-- the native `gO` document-symbol jumplist, and Telescope lsp_document_symbols.

return {
  {
    "stevearc/aerial.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    cmd = { "AerialToggle", "AerialOpen", "AerialNavToggle" },
    keys = {
      { "<leader>cO", "<cmd>AerialToggle!<cr>", desc = "Outline (Aerial)" },
      { "<leader>cn", "<cmd>AerialNavToggle<cr>", desc = "Outline nav (Aerial)" },
    },
    opts = {
      -- Prefer LSP symbols; fall back to treesitter where no LSP is attached.
      backends = { "lsp", "treesitter", "markdown", "man" },
      layout = {
        default_direction = "right",
        min_width = 30,
        max_width = { 40, 0.25 },
      },
      attach_mode = "global",
      show_guides = true,
      filter_kind = false, -- show every symbol kind
      keymaps = {
        ["<CR>"] = "actions.jump",
        ["o"] = "actions.jump",
        ["q"] = "actions.close",
      },
    },
  },
}
