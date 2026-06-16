-- Formatting: conform.nvim (oxfmt for web, Ruff for Python, Stylua for Lua)
-- oxfmt is the oxc formatter, installed as a bun global; it auto-detects per-project
-- oxfmt config when present. conform has no built-in oxfmt yet, so it's defined below.
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
          require("conform").format({ async = true, lsp_format = "fallback" })
        end,
        desc = "Format buffer",
      },
    },
    opts = {
      formatters = {
        oxfmt = {
          command = "oxfmt",
          args = { "--stdin-filepath", "$FILENAME" },
          stdin = true,
        },
      },
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
        lsp_format = "fallback",
      },
    },
  },
}
