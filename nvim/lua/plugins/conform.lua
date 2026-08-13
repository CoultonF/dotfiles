-- Formatting: conform.nvim (oxfmt for web, Ruff for Python, Stylua for Lua)
-- oxfmt is installed as a bun global and auto-detects each project's config.
-- ruff/stylua/sqlfluff are provided by nix (see home.nix).

return {
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    keys = {
      {
        "<leader>fm",
        function()
          require("conform").format({ async = true, lsp_format = "never" })
        end,
        desc = "Format buffer",
      },
    },
    opts = {
      formatters_by_ft = {
        javascript = { "oxfmt" },
        javascriptreact = { "oxfmt" },
        typescript = { "oxfmt" },
        typescriptreact = { "oxfmt" },
        css = { "oxfmt" },
        scss = { "oxfmt" },
        html = { "oxfmt" },
        json = { "oxfmt" },
        jsonc = { "oxfmt" },
        yaml = { "oxfmt" },
        markdown = { "oxfmt" },
        python = { "ruff_organize_imports", "ruff_format" },
        lua = { "stylua" },
        sql = { "sqlfluff" },
      },
      format_on_save = {
        timeout_ms = 500,
        lsp_format = "never",
      },
    },
  },
}
