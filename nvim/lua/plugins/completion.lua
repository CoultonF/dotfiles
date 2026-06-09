-- Completion: blink.cmp (replaces the nvim-cmp stack)

return {
  {
    "saghen/blink.cmp",
    version = "1.*", -- downloads prebuilt fuzzy binary; no Rust toolchain needed (devcontainer-friendly)
    event = "InsertEnter",
    dependencies = {
      "rafamadriz/friendly-snippets",
      {
        "L3MON4D3/LuaSnip",
        version = "v2.*",
        build = "make install_jsregexp",
        config = function()
          require("luasnip.loaders.from_vscode").lazy_load()
        end,
      },
    },
    opts = {
      keymap = { preset = "enter" }, -- <CR> accepts, <C-n>/<C-p> select, <Tab>/<S-Tab> jump snippet fields
      appearance = { nerd_font_variant = "mono" },
      snippets = { preset = "luasnip" },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
      },
      signature = { enabled = true },
      fuzzy = { implementation = "prefer_rust_with_warning" },
    },
    opts_extend = { "sources.default" },
  },

  -- Autopairs for brackets/quotes (tags are handled by nvim-ts-autotag).
  -- blink.cmp handles its own bracket insertion, so no cmp confirm-done hook is needed.
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {
      check_ts = true,
    },
  },
}
