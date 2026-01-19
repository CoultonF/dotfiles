-- ToggleTerm: Terminal integration

return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    keys = {
      { "<C-t>", "<cmd>ToggleTerm<CR>", desc = "Toggle terminal" },
      { "<leader>tf", "<cmd>ToggleTerm direction=float<CR>", desc = "Float terminal" },
      { "<leader>th", "<cmd>ToggleTerm direction=horizontal<CR>", desc = "Horizontal terminal" },
      { "<leader>tv", "<cmd>ToggleTerm direction=vertical<CR>", desc = "Vertical terminal" },
    },
    opts = {
      size = function(term)
        if term.direction == "horizontal" then
          return 15
        elseif term.direction == "vertical" then
          return vim.o.columns * 0.4
        end
      end,
      open_mapping = [[<C-t>]],
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
      shell = "bash -i",  -- Interactive mode to load .bashrc
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

      -- Terminal mode mappings
      function _G.set_terminal_keymaps()
        local term_opts = { buffer = 0 }
        vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], term_opts)
        vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], term_opts)
        vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], term_opts)
        vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], term_opts)
        vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], term_opts)
      end

      vim.cmd("autocmd! TermOpen term://* lua set_terminal_keymaps()")
    end,
  },
}
