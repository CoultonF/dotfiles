return {
  "tpope/vim-fugitive",
  cmd = { "Git", "G", "Gdiffsplit", "Gvdiffsplit" },
  keys = {
    { "<leader>gv", "<cmd>Git<cr>", desc = "Git status (fugitive)" },
    { "<leader>gV", "<cmd>Gvdiffsplit<cr>", desc = "Git diff split (vertical)" },
  },
}
