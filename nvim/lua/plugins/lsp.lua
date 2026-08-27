-- LSP Configuration

return {
  -- Mason: gap-filler only. Core servers are provisioned deterministically via
  -- nix/bun (see home.nix); Mason installs just the long-tail and is set to
  -- APPEND its bin dir to PATH so nix/bun binaries always take precedence.
  {
    "mason-org/mason.nvim",
    cmd = "Mason",
    opts = {
      PATH = "append",
      ui = {
        border = "rounded",
        icons = {
          package_installed = "✓",
          package_pending = "➜",
          package_uninstalled = "✗",
        },
      },
    },
  },

  -- Mason LSPConfig bridge — only the servers nix/bun do NOT provide.
  -- (lua_ls, ruff -> nix; basedpyright, html/css/json -> bun; oxlint -> bun.)
  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = { "mason-org/mason.nvim" },
    opts = {
      ensure_installed = {
        "yamlls",
        "bashls",
        "dockerls",
        "tailwindcss",
      },
      automatic_enable = false,
    },
  },

  -- LSP Configuration
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "mason-org/mason.nvim",
      "mason-org/mason-lspconfig.nvim",
      "saghen/blink.cmp",
      { "folke/lazydev.nvim", ft = "lua", opts = {} }, -- Neovim Lua API completion (neodev successor)
    },
    config = function()
      vim.lsp.config("*", {
        capabilities = require("blink.cmp").get_lsp_capabilities(),
      })

      local venv = require("utils.venv")

      local lsp_group = vim.api.nvim_create_augroup("LspConfig", { clear = true })
      vim.api.nvim_create_autocmd("LspAttach", {
        group = lsp_group,
        callback = function(event)
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if not client then
            return
          end

          local bufnr = event.buf
          local map = function(keys, func, desc)
            vim.keymap.set("n", keys, func, { buffer = bufnr, desc = "LSP: " .. desc })
          end

          -- Keep definition direct so gd never opens a picker.
          map("gd", vim.lsp.buf.definition, "Go to definition")
          map("gD", vim.lsp.buf.declaration, "Go to declaration")
          map("gh", vim.lsp.buf.hover, "Hover documentation")
          map("gk", vim.lsp.buf.signature_help, "Signature help")
          map("<leader>rn", vim.lsp.buf.rename, "Rename symbol")
          map("<leader>ca", vim.lsp.buf.code_action, "Code action")

          if client:supports_method("textDocument/inlayHint") then
            map("<leader>ch", function()
              vim.lsp.inlay_hint.enable(
                not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }),
                { bufnr = bufnr }
              )
            end, "Toggle inlay hints")
          end

          if client.name == "ruff" then
            client.server_capabilities.hoverProvider = false
          elseif client.name == "oxlint" then
            map("<leader>cF", "<cmd>LspOxlintFixAll<CR>", "Oxlint fix all")
          end
        end,
      })

      local servers = {
        lua_ls = {
          settings = {
            Lua = {
              workspace = { checkThirdParty = false },
              telemetry = { enable = false },
              diagnostics = {
                globals = { "vim" },
              },
            },
          },
        },
        tsc = {
          cmd = { "tsc", "--lsp", "--stdio" },
        },
        html = {},
        cssls = {},
        jsonls = {},
        yamlls = {},
        bashls = {},
        dockerls = {},
        tailwindcss = {
          settings = {
            tailwindCSS = {
              experimental = {
                classRegex = {
                  "tw`([^`]*)",
                  'tw="([^"]*)',
                  'tw={"([^"}]*)',
                  "cva\\(([^)]*)\\)",
                  "cx\\(([^)]*)\\)",
                },
              },
            },
          },
        },
        oxlint = {},
        basedpyright = {
          before_init = function(_, config)
            local py = venv.find_python(config.root_dir)
            if py then
              config.settings = vim.tbl_deep_extend("force", config.settings or {}, {
                python = { pythonPath = py },
              })
            end
          end,
          settings = {
            basedpyright = {
              analysis = {
                diagnosticMode = "openFilesOnly",
                inlayHints = {
                  variableTypes = true,
                  functionReturnTypes = true,
                  callArgumentNames = true,
                },
              },
            },
          },
        },
        ruff = {},
        postgres_lsp = {},
      }

      local enabled_servers = {
        "lua_ls",
        "tsc",
        "html",
        "cssls",
        "jsonls",
        "yamlls",
        "bashls",
        "dockerls",
        "tailwindcss",
        "oxlint",
        "basedpyright",
        "ruff",
        "postgres_lsp",
      }

      for server, config in pairs(servers) do
        vim.lsp.config(server, config)
      end
      vim.lsp.enable(enabled_servers)

      vim.diagnostic.config({
        virtual_text = false,
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = " ",
            [vim.diagnostic.severity.WARN] = " ",
            [vim.diagnostic.severity.HINT] = "󰌵 ",
            [vim.diagnostic.severity.INFO] = " ",
          },
          numhl = {
            [vim.diagnostic.severity.ERROR] = "DiagnosticSignError",
            [vim.diagnostic.severity.WARN] = "DiagnosticSignWarn",
            [vim.diagnostic.severity.HINT] = "DiagnosticSignHint",
            [vim.diagnostic.severity.INFO] = "DiagnosticSignInfo",
          },
        },
        underline = true,
        update_in_insert = false,
        severity_sort = true,
        float = {
          border = "rounded",
          source = true,
        },
      })
    end,
  },
}
