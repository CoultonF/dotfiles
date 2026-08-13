-- Test: neotest for running tests

return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      -- Test adapters
      "nvim-neotest/neotest-python",
      "marilari88/neotest-vitest",
    },
    keys = {
      -- Test mappings (like VS Code leader t)
      { "<leader>tt", function() require("neotest").summary.toggle() end, desc = "Test summary" },
      { "<leader>tr", function() require("neotest").run.run() end, desc = "Run nearest test" },
      { "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Run file tests" },
      { "<leader>ta", function() require("neotest").run.run(vim.fn.getcwd()) end, desc = "Run all tests" },
      { "<leader>tl", function() require("neotest").run.run_last() end, desc = "Run last test" },
      { "<leader>ts", function() require("neotest").run.stop() end, desc = "Stop test" },
      { "<leader>to", function() require("neotest").output.open({ enter = true, auto_close = true }) end, desc = "Test output" },
      { "<leader>tO", function() require("neotest").output_panel.toggle() end, desc = "Toggle output panel" },
      { "<leader>td", function() require("neotest").run.run({ strategy = "dap" }) end, desc = "Debug nearest test" },
      { "[T", function() require("neotest").jump.prev({ status = "failed" }) end, desc = "Prev failed test" },
      { "]T", function() require("neotest").jump.next({ status = "failed" }) end, desc = "Next failed test" },
    },
    opts = function()
      return {
        adapters = {
          require("neotest-python")({
            dap = { justMyCode = false },
            runner = "pytest",
            python = function(root)
              return require("utils.venv").find_python(root) or "python"
            end,
          }),
          require("neotest-vitest"),
        },
        status = {
          virtual_text = true,
        },
        output = {
          open_on_run = true,
        },
        quickfix = {
          open = function()
            vim.cmd("copen")
          end,
        },
      }
    end,
    config = function(_, opts)
      require("neotest").setup(opts)
    end,
  },
}
