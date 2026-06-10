-- LSP Configuration

return {
  -- Mason: Package manager for LSP servers, linters, formatters
  {
    "williamboman/mason.nvim",
    cmd = "Mason",
    build = ":MasonUpdate",
    opts = {
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

  -- Mason LSPConfig bridge
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "mason.nvim" },
    opts = {
      ensure_installed = {
        "lua_ls",
        "vtsls",
        "html",
        "cssls",
        "jsonls",
        "yamlls",
        "bashls",
        "dockerls",
        "tailwindcss",
        "eslint",
        "pyright",
        "ruff",
      },
      -- servers are configured + enabled explicitly below via vim.lsp.config/enable
      automatic_enable = false,
    },
  },

  -- Neovim Lua API completion (replaces archived neodev.nvim)
  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {},
  },

  -- LSP Configuration
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "mason.nvim",
      "mason-lspconfig.nvim",
    },
    config = function()
      -- LSP capabilities with completion (blink.cmp)
      local capabilities = require("blink.cmp").get_lsp_capabilities()

      -- On attach: Set up keymaps when LSP attaches to buffer
      local on_attach = function(client, bufnr)
        local map = function(keys, func, desc)
          vim.keymap.set("n", keys, func, { buffer = bufnr, desc = "LSP: " .. desc })
        end

        -- Navigation (like VS Code gd, gr)
        map("gd", vim.lsp.buf.definition, "Go to definition")
        map("gD", vim.lsp.buf.declaration, "Go to declaration")
        map("gr", vim.lsp.buf.references, "Go to references")
        map("gi", vim.lsp.buf.implementation, "Go to implementation")
        map("gt", vim.lsp.buf.type_definition, "Go to type definition")

        -- Hover and signature
        map("gh", vim.lsp.buf.hover, "Hover documentation")
        map("gk", vim.lsp.buf.signature_help, "Signature help")

        -- Actions (like VS Code leader rn)
        map("<leader>rn", vim.lsp.buf.rename, "Rename symbol")
        map("<leader>ca", vim.lsp.buf.code_action, "Code action")

        -- Workspace
        map("<leader>cs", vim.lsp.buf.workspace_symbol, "Workspace symbols")

        -- Inlay hints (nvim 0.12 native). Formatting is owned by conform.nvim (<leader>fm).
        if client:supports_method("textDocument/inlayHint") then
          vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
        end
        map("<leader>ch", function()
          vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = 0 }), { bufnr = 0 })
        end, "Toggle inlay hints")
      end

      -- Configure servers
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
        vtsls = {
          settings = {
            typescript = {
              inlayHints = {
                parameterNames = { enabled = "literals" },
                parameterTypes = { enabled = true },
                variableTypes = { enabled = true },
                propertyDeclarationTypes = { enabled = true },
                functionLikeReturnTypes = { enabled = true },
                enumMemberValues = { enabled = true },
              },
            },
            javascript = {
              inlayHints = {
                parameterNames = { enabled = "literals" },
                variableTypes = { enabled = true },
                functionLikeReturnTypes = { enabled = true },
              },
            },
          },
        },
        html = {},
        cssls = {},
        jsonls = {},
        yamlls = {},
        bashls = {},
        dockerls = {},
        tailwindcss = {},
        eslint = {
          on_attach = function(client, bufnr)
            on_attach(client, bufnr)
            vim.api.nvim_create_autocmd("BufWritePre", {
              -- per-buffer group so LSP reattach replaces instead of stacking duplicates
              group = vim.api.nvim_create_augroup("EslintFixAll." .. bufnr, { clear = true }),
              buffer = bufnr,
              callback = function()
                local clients = vim.lsp.get_clients({ bufnr = bufnr, name = "eslint" })
                if #clients == 0 then return end
                clients[1]:request_sync("workspace/executeCommand", {
                  command = "eslint.applyAllFixes",
                  arguments = {
                    {
                      uri = vim.uri_from_bufnr(bufnr),
                      version = vim.lsp.util.buf_versions[bufnr],
                    },
                  },
                }, 3000, bufnr)
              end,
            })
          end,
        },
        pyright = {
          settings = {
            python = {
              analysis = {
                typeCheckingMode = "basic",
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
      }

      -- Setup each server using new vim.lsp.config API (nvim 0.11+)
      local server_names = {}
      for server, config in pairs(servers) do
        config.capabilities = capabilities
        config.on_attach = config.on_attach or on_attach
        vim.lsp.config(server, config)
        table.insert(server_names, server)
      end
      vim.lsp.enable(server_names)

      -- Diagnostic configuration
      vim.diagnostic.config({
        virtual_text = {
          prefix = "●",
        },
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
          source = "always",
        },
      })
    end,
  },
}
