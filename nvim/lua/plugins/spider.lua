-- nvim-spider: w/e/b/ge that move by subword (camelCase, snake_case)
-- Bound to <leader>-prefixed keys so plain w/e/b keep standard word motion.

return {
  {
    "chrisgrieser/nvim-spider",
    keys = {
      { "<leader>w", "<cmd>lua require('spider').motion('w')<CR>", mode = { "n", "o", "x" }, desc = "Subword forward" },
      { "<leader>e", "<cmd>lua require('spider').motion('e')<CR>", mode = { "n", "o", "x" }, desc = "Subword end" },
      { "<leader>b", "<cmd>lua require('spider').motion('b')<CR>", mode = { "n", "o", "x" }, desc = "Subword back" },
      { "<leader>E", "<cmd>lua require('spider').motion('ge')<CR>", mode = { "n", "o", "x" }, desc = "Subword prev end" },
    },
    opts = {
      skipInsignificantPunctuation = true,
    },
  },
}
