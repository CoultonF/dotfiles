-- nvim-lint: diagnostics for filetypes not covered by an LSP.
-- Binaries are provisioned via nix (see home.nix): sqlfluff, hadolint,
-- shellcheck, yamllint, markdownlint-cli (binary `markdownlint`).
-- ESLint (JS/TS) and Ruff (Python) stay on their LSPs, not here.

return {
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufWritePost" },
    config = function()
      local lint = require("lint")

      lint.linters_by_ft = {
        sql = { "sqlfluff" },
        dockerfile = { "hadolint" },
        sh = { "shellcheck" },
        bash = { "shellcheck" },
        yaml = { "yamllint" },
        markdown = { "markdownlint" },
      }

      -- The explicit Postgres CLI dialect wins over project .sqlfluff /
      -- pyproject.toml [tool.sqlfluff] settings. The filename is appended
      -- automatically by nvim-lint (append_fname).
      if lint.linters.sqlfluff then
        lint.linters.sqlfluff.args = { "lint", "--format=json", "--dialect=postgres" }
      end

      local grp = vim.api.nvim_create_augroup("NvimLint", { clear = true })
      vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
        group = grp,
        callback = function(event)
          local bufnr = event.buf
          if vim.bo[bufnr].buftype == "" and vim.bo[bufnr].modifiable then
            vim.api.nvim_buf_call(bufnr, function()
              lint.try_lint()
            end)
          end
        end,
      })
    end,
  },
}
