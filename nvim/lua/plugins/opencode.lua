-- OpenCode: AI coding assistant integration

-- Remote server port (use SSH tunnel: devpod ssh <workspace> -- -R 41920:localhost:41920)
local OPENCODE_PORT = 41920

return {
  {
    "nickvandyke/opencode.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    init = function()
      -- Configure before plugin loads
      -- For remote/container environments, connect to host via SSH tunnel
      if os.getenv("SSH_TTY")
        or os.getenv("container")
        or os.getenv("DEVPOD_WORKSPACE_ID")
        or os.getenv("CODESPACES")
        or os.getenv("REMOTE_CONTAINERS")
        or vim.fn.filereadable("/.dockerenv") == 1
      then
        vim.g.opencode_opts = {
          port = OPENCODE_PORT,
          provider = { enabled = false },
        }
      end
    end,
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
