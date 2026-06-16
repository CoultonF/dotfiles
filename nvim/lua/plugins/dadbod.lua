-- Database tooling
--   * rainfrog (Postgres TUI) for browsing/executing queries — launched in a
--     toggleterm float via <leader>D (see utils/db.lua). Replaces vim-dadbod-ui.
--   * vim-dadbod core for ad-hoc in-buffer `:DB <query>` execution.
--   * vim-dadbod-completion as the blink SQL completion source (plugins/completion.lua).

return {
  -- In-buffer query execution
  { "tpope/vim-dadbod", cmd = "DB" },

  -- Schema-aware completion for SQL buffers (wired into blink.cmp)
  {
    "kristijanhusak/vim-dadbod-completion",
    dependencies = { "tpope/vim-dadbod" },
    ft = { "sql", "mysql", "plsql" },
  },

  -- Load DATABASE_URL (and friends) from a project .env for :DB
  { "tpope/vim-dotenv", lazy = true },

  -- rainfrog launcher: augment the existing toggleterm spec with a keymap so
  -- toggleterm is loaded on first use. <leader>db is taken by dap (breakpoint),
  -- so the Postgres TUI lives on <leader>D (Database).
  {
    "akinsho/toggleterm.nvim",
    optional = true,
    keys = {
      { "<leader>D", function() require("utils.db").toggle_rainfrog() end, desc = "Database (rainfrog)" },
    },
  },
}
