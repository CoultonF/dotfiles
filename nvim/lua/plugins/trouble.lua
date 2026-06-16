-- trouble.nvim: a polished list for references / definitions / diagnostics.
-- Activates the catppuccin `lsp_trouble` integration already enabled in
-- plugins/colorscheme.lua (which was previously a no-op).
--
-- gr/gi/gt are global (the primary navigation the user cares about); the list
-- views live under the existing <leader>c (Code) group to avoid colliding with
-- the <leader>x explorer toggle (neo-tree.lua). The duplicate gr/gi/gt buffer
-- maps were removed from plugins/lsp.lua on_attach.

return {
  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    opts = {
      focus = true,
    },
    keys = {
      -- Primary navigation (global, VS Code-style muscle memory)
      { "gr", "<cmd>Trouble lsp_references toggle focus=true<cr>", desc = "References (Trouble)" },
      { "gi", "<cmd>Trouble lsp_implementations toggle<cr>", desc = "Implementations (Trouble)" },
      { "gt", "<cmd>Trouble lsp_type_definitions toggle<cr>", desc = "Type definitions (Trouble)" },
      -- List views under the Code group
      { "<leader>cx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics (Trouble)" },
      { "<leader>cX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Buffer diagnostics (Trouble)" },
      { "<leader>cl", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", desc = "LSP defs/refs panel (Trouble)" },
      { "<leader>cq", "<cmd>Trouble qflist toggle<cr>", desc = "Quickfix (Trouble)" },
      -- Navigate items without leaving the buffer
      { "[x", function() require("trouble").prev({ skip_groups = true, jump = true }) end, desc = "Prev Trouble item" },
      { "]x", function() require("trouble").next({ skip_groups = true, jump = true }) end, desc = "Next Trouble item" },
    },
  },
}
