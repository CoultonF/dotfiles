-- Overseer: run VS Code tasks.json and custom tasks

return {
  {
    "stevearc/overseer.nvim",
    keys = {
      { "<leader>or", "<cmd>OverseerRun<cr>", desc = "Run task" },
      { "<leader>ot", "<cmd>OverseerToggle<cr>", desc = "Toggle task list" },
    },
    opts = {},
  },
}
