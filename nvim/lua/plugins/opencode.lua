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
    opts = {
      -- Auto-connect to opencode running in cwd
      auto_connect = true,
      -- Terminal provider (toggleterm, native, etc.)
      provider = "auto",
      -- Auto-approve permissions
      auto_approve = false,
    },
  },
}
