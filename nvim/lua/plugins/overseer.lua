-- Overseer: run VS Code tasks.json and custom tasks

return {
  {
    "stevearc/overseer.nvim",
    -- <leader>o is now the OMP prefix; run Overseer via :OverseerRun / :OverseerToggle
    cmd = { "OverseerRun", "OverseerToggle" },
    opts = {},
  },
}
