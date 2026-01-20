-- OpenCode: AI coding assistant integration

return {
  {
    "nickvandyke/opencode.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      -- Normal mode: ask opencode
      {
        "<leader>oa",
        function()
          require("opencode").ask()
        end,
        desc = "OpenCode Ask",
      },
      -- Visual mode: ask about selection
      {
        "<leader>oa",
        function()
          require("opencode").ask("@selection: ")
        end,
        mode = "v",
        desc = "OpenCode Ask Selection",
      },
      -- Select from available actions
      {
        "<leader>os",
        function()
          require("opencode").select()
        end,
        desc = "OpenCode Select Action",
      },
      -- Run command
      {
        "<leader>oc",
        function()
          require("opencode").command()
        end,
        desc = "OpenCode Command",
      },
      -- Prompt with context
      {
        "<leader>op",
        function()
          require("opencode").prompt()
        end,
        desc = "OpenCode Prompt",
      },
    },
    config = function()
      -- Plugin may not have setup(), just load it
      local ok, opencode = pcall(require, "opencode")
      if not ok then
        vim.notify("opencode.nvim failed to load", vim.log.levels.WARN)
      end
    end,
  },
}
