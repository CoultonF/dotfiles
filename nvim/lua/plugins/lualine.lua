-- Lualine: Status line

return {
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        theme = "catppuccin",
        component_separators = { left = "", right = "" },
        section_separators = { left = "", right = "" },
        globalstatus = true,
        disabled_filetypes = {
          statusline = { "dashboard", "alpha" },
        },
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = {
          {
            "filename",
            path = 1, -- Relative path
            symbols = {
              modified = "●",
              readonly = "",
              unnamed = "[No Name]",
            },
          },
        },
        lualine_x = {
          {
            -- Show OpenCode connection status
            function()
              local ok, opencode = pcall(require, "opencode")
              if ok and opencode.is_connected and opencode.is_connected() then
                return "󰚩 OC"
              end
              return ""
            end,
            color = { fg = "#a6e3a1" },
          },
          "encoding",
          "fileformat",
          "filetype",
        },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
      inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = { "filename" },
        lualine_x = { "location" },
        lualine_y = {},
        lualine_z = {},
      },
      extensions = { "lazy", "mason", "oil", "quickfix" },
    },
  },
}
