-- ToggleTerm: Terminal integration

return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    keys = {
      { "<C-t>", "<cmd>ToggleTerm<CR>", desc = "Toggle terminal" },
      { "<leader>Tf", "<cmd>ToggleTerm direction=float<CR>", desc = "Float terminal" },
      { "<leader>Th", "<cmd>ToggleTerm direction=horizontal<CR>", desc = "Horizontal terminal" },
      { "<leader>Tv", "<cmd>ToggleTerm direction=vertical<CR>", desc = "Vertical terminal" },
    },
    opts = {
      size = function(term)
        if term.direction == "horizontal" then
          return 15
        elseif term.direction == "vertical" then
          return vim.o.columns * 0.4
        end
      end,
      hide_numbers = true,
      shade_filetypes = {},
      shade_terminals = true,
      shading_factor = 2,
      start_in_insert = true,
      insert_mappings = true,
      terminal_mappings = true,
      persist_size = true,
      persist_mode = true,
      direction = "float",
      close_on_exit = true,
      float_opts = {
        border = "curved",
        winblend = 0,
        highlights = {
          border = "Normal",
          background = "Normal",
        },
      },
    },
    config = function(_, opts)
      require("toggleterm").setup(opts)

      local group = vim.api.nvim_create_augroup("ToggleTermMappings", { clear = true })
      vim.api.nvim_create_autocmd("TermOpen", {
        group = group,
        pattern = "term://*",
        callback = function(event)
          local term_opts = { buffer = event.buf, silent = true }
          vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], term_opts)
          vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], term_opts)
          vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], term_opts)
          vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], term_opts)
          vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], term_opts)
        end,
      })
    end,
  },
}
