-- OSC 52 clipboard plugin for remote/container environments
return {
  "ojroques/nvim-osc52",
  event = "VeryLazy",
  config = function()
    require("osc52").setup({
      max_length = 0, -- Maximum length of selection (0 for no limit)
      silent = false, -- Disable message on successful copy
      trim = false, -- Trim surrounding whitespaces before copy
    })

    -- Auto-detect container/remote environments
    local in_container = os.getenv("SSH_TTY")
      or os.getenv("container")
      or os.getenv("DEVPOD_WORKSPACE_ID")
      or os.getenv("CODESPACES")
      or os.getenv("REMOTE_CONTAINERS")
      or vim.fn.filereadable("/.dockerenv") == 1
      or vim.fn.has("wsl") == 1

    if in_container then
      -- Use OSC 52 for yanking in containers
      vim.keymap.set("n", "<leader>y", require("osc52").copy_operator, { expr = true, desc = "Yank to system clipboard" })
      vim.keymap.set("n", "<leader>Y", "<leader>y_", { remap = true, desc = "Yank line to system clipboard" })
      vim.keymap.set("v", "<leader>y", require("osc52").copy_visual, { desc = "Yank to system clipboard" })
    end
  end,
}
