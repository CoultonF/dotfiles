-- Overseer: run VS Code tasks.json and custom tasks

return {
  {
    "stevearc/overseer.nvim",
    cmd = { "OverseerRun", "OverseerToggle" },
    keys = {
      { "<leader>ot", "<cmd>OverseerRun<CR>", desc = "Run task" },
      { "<leader>oo", "<cmd>OverseerToggle<CR>", desc = "Toggle task panel" },
    },
    opts = {},
  },
}
