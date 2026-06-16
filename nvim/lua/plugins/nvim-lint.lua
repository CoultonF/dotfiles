-- nvim-lint: diagnostics for filetypes not covered by an LSP.
-- Binaries are provisioned via nix (see home.nix): sqlfluff, hadolint,
-- shellcheck, yamllint, markdownlint-cli (binary `markdownlint`).
-- ESLint (JS/TS) and Ruff (Python) stay on their LSPs, not here.

return {
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufWritePost", "InsertLeave" },
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

      -- Default sqlfluff to the postgres dialect. A project .sqlfluff /
      -- pyproject.toml [tool.sqlfluff] overrides this. The filename is appended
      -- automatically by nvim-lint (append_fname).
      if lint.linters.sqlfluff then
        lint.linters.sqlfluff.args = { "lint", "--format=json", "--dialect=postgres" }
      end

      local grp = vim.api.nvim_create_augroup("NvimLint", { clear = true })
      vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "InsertLeave" }, {
        group = grp,
        callback = function()
          -- Only lint normal, modifiable buffers.
          if vim.bo.buftype == "" then
            require("lint").try_lint()
          end
        end,
      })
    end,
  },
}
