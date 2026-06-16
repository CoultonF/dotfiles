-- LSP Configuration

return {
  -- Mason: gap-filler only. Core servers are provisioned deterministically via
  -- nix/bun (see home.nix); Mason installs just the long-tail and is set to
  -- APPEND its bin dir to PATH so nix/bun binaries always take precedence.
  {
    "williamboman/mason.nvim",
    cmd = "Mason",
    build = ":MasonUpdate",
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
  -- (lua_ls, ruff -> nix; vtsls, basedpyright, html/css/json -> bun; oxlint -> bun.)
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "mason.nvim" },
    opts = {
      ensure_installed = {
        "yamlls",
        "bashls",
        "dockerls",
        "tailwindcss",
      },
      automatic_installation = false,
    },
  },

  -- LSP Configuration
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "mason.nvim",
      "mason-lspconfig.nvim",
      { "folke/lazydev.nvim", ft = "lua", opts = {} }, -- Neovim Lua API completion (neodev successor)
      "yioneko/nvim-vtsls", -- vtsls power-commands (organize/add-missing imports, source-definition)
    },
    config = function()
      -- LSP capabilities with completion (blink.cmp)
      local capabilities = require("blink.cmp").get_lsp_capabilities()

      local venv = require("utils.venv")

      -- On attach: Set up keymaps when LSP attaches to buffer
      local on_attach = function(client, bufnr)
        local map = function(keys, func, desc)
          vim.keymap.set("n", keys, func, { buffer = bufnr, desc = "LSP: " .. desc })
        end

        -- Navigation. gr/gi/gt are owned by trouble.nvim (plugins/trouble.lua).
        map("gd", vim.lsp.buf.definition, "Go to definition")
        map("gD", vim.lsp.buf.declaration, "Go to declaration")

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

        -- Highlight other references of the symbol under the cursor.
        if client:supports_method("textDocument/documentHighlight") then
          local hl = vim.api.nvim_create_augroup("LspDocHl" .. bufnr, { clear = true })
          vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
            group = hl,
            buffer = bufnr,
            callback = vim.lsp.buf.document_highlight,
          })
          vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
            group = hl,
            buffer = bufnr,
            callback = vim.lsp.buf.clear_references,
          })
        end

        -- vtsls power-commands for TS/TSX monorepos (yioneko/nvim-vtsls).
        if client.name == "vtsls" then
          local vtsls = require("vtsls")
          -- gD jumps to the real source, skipping .d.ts (the monorepo pain point).
          map("gD", function() vtsls.commands.goto_source_definition(0) end, "Go to source definition")
          map("<leader>co", function() vtsls.commands.organize_imports(0) end, "Organize imports")
          map("<leader>cM", function() vtsls.commands.add_missing_imports(0) end, "Add missing imports")
          map("<leader>cu", function() vtsls.commands.remove_unused_imports(0) end, "Remove unused imports")
          map("<leader>cF", function() vtsls.commands.fix_all(0) end, "Fix all (ts)")
        end
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
            vtsls = {
              autoUseWorkspaceTsdk = true, -- use each package's local typescript (monorepo)
              experimental = {
                completion = { enableServerSideFuzzyMatch = true },
              },
            },
            typescript = {
              tsserver = { maxTsServerMemory = 8192 }, -- raise for large monorepos
              updateImportsOnFileMove = { enabled = "always" },
              preferences = { includePackageJsonAutoImports = "auto" },
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
        tailwindcss = {
          settings = {
            tailwindCSS = {
              experimental = {
                -- Recognise tailwind classes inside tw``, tw="", cva(), cx()
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
        -- oxlint LSP (oxc linter). Installed as a bun global; run via `oxlint --lsp`.
        -- Applies all auto-fixable issues on save via the source.fixAll.oxc code action.
        oxlint = {
          cmd = { "oxlint", "--lsp" },
          on_attach = function(client, bufnr)
            on_attach(client, bufnr)
            vim.api.nvim_create_autocmd("BufWritePre", {
              buffer = bufnr,
              callback = function()
                vim.lsp.buf.code_action({
                  context = { only = { "source.fixAll.oxc" }, diagnostics = {} },
                  apply = true,
                })
              end,
            })
          end,
        },
        -- basedpyright: pyright superset, better inlay hints + monorepo perf.
        -- Per-package venv is resolved by before_init (see utils/venv.lua).
        basedpyright = {
          before_init = function(_, config)
            local py = venv.find_python(config.root_dir)
            if py then
              config.settings = config.settings or {}
              config.settings.python = vim.tbl_deep_extend("force", config.settings.python or {}, {
                pythonPath = py,
              })
            end
          end,
          settings = {
            basedpyright = {
              analysis = {
                typeCheckingMode = "standard",
                autoSearchPaths = true,
                useLibraryCodeForTypes = true,
                diagnosticMode = "openFilesOnly", -- monorepo-friendly (don't scan the whole tree)
                inlayHints = {
                  variableTypes = true,
                  functionReturnTypes = true,
                  callArgumentNames = true,
                },
              },
            },
          },
        },
        ruff = {}, -- fast lint/code-actions; formatting owned by conform (ruff_format)
        postgres_lsp = {}, -- Postgres SQL LSP (binary: postgrestools)
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
          source = true, -- nvim 0.11+: boolean replaces the legacy "always"
        },
      })
    end,
  },
}
