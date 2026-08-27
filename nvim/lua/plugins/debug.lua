-- Debug: nvim-dap for Python and JavaScript debugging

return {
  -- DAP core
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      -- DAP UI
      {
        "rcarriga/nvim-dap-ui",
        dependencies = { "nvim-neotest/nvim-nio" },
        keys = {
          { "<leader>du", function() require("dapui").toggle({}) end, desc = "DAP UI" },
          { "<leader>de", function() require("dapui").eval() end, desc = "Eval", mode = { "n", "v" } },
        },
        opts = {},
        config = function(_, opts)
          local dap = require("dap")
          local dapui = require("dapui")
          dapui.setup(opts)
          dap.listeners.after.event_initialized["dapui_config"] = function()
            dapui.open({})
          end
          dap.listeners.before.event_terminated["dapui_config"] = function()
            dapui.close({})
          end
          dap.listeners.before.event_exited["dapui_config"] = function()
            dapui.close({})
          end
        end,
      },
      -- Virtual text
      {
        "theHamsta/nvim-dap-virtual-text",
        opts = {},
      },
      -- Mason DAP
      {
        "jay-babu/mason-nvim-dap.nvim",
        dependencies = "mason.nvim",
        cmd = { "DapInstall", "DapUninstall" },
        opts = {
          automatic_installation = false,
          ensure_installed = {
            "python",
            "js",
          },
        },
      },
      -- Python DAP
      {
        "mfussenegger/nvim-dap-python",
        keys = {
          { "<leader>dPt", function() require("dap-python").test_method() end, desc = "Debug test method" },
          { "<leader>dPc", function() require("dap-python").test_class() end, desc = "Debug test class" },
        },
        config = function()
          local mason_python = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python"
          require("dap-python").setup(mason_python, {
            pythonPath = function()
              return require("utils.venv").find_python(vim.api.nvim_buf_get_name(0)) or "python"
            end,
          })
        end,
      },
    },
    keys = {
      -- Debug controls (like VS Code leader d mappings)
      { "<leader>dd", function() require("dapui").toggle({}) end, desc = "Debug UI" },
      { "<leader>da", function() require("dap").continue() end, desc = "Start/Continue" },
      { "<leader>dc", function() require("dap").continue() end, desc = "Continue" },
      { "<leader>dx", function() require("dap").terminate() end, desc = "Terminate" },
      { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Toggle breakpoint" },
      { "<leader>dB", function() require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: ")) end, desc = "Conditional breakpoint" },
      { "<leader>dD", function() require("dap").clear_breakpoints() end, desc = "Clear all breakpoints" },
      { "<leader>dl", function() require("dap").set_breakpoint(nil, nil, vim.fn.input("Log point message: ")) end, desc = "Log point" },
      { "<leader>dr", function() require("dap").repl.toggle() end, desc = "Toggle REPL" },
      { "<leader>ds", function() require("dap").step_over() end, desc = "Step over" },
      { "<leader>di", function() require("dap").step_into() end, desc = "Step into" },
      { "<leader>do", function() require("dap").step_out() end, desc = "Step out" },
      { "<leader>dj", function() require("dap").down() end, desc = "Down" },
      { "<leader>dk", function() require("dap").up() end, desc = "Up" },
      { "<leader>dp", function() require("dap").pause() end, desc = "Pause" },
      -- Web server debug picker (launch or attach individual servers)
      { "<leader>dw", function()
        local dap = require("dap")
        local configs = dap.configurations.python or {}
        local web_configs = vim.tbl_filter(function(c)
          return c.name:match("FastAPI") or c.name:match("Flask")
              or c.name:match("RCOM") or c.name:match("Attach")
              or c.name:match("API w/")
        end, configs)
        if #web_configs == 0 then
          vim.notify("No web server debug configs found", vim.log.levels.WARN)
          return
        end
        vim.ui.select(web_configs, {
          prompt = "Select web server debug config:",
          format_item = function(c) return c.name end,
        }, function(config)
          if config then dap.run(config) end
        end)
      end, desc = "Debug web server" },
      -- Attach All: compound attach to both FastAPI and Flask debugpy sessions
      { "<leader>dW", function()
        local dap = require("dap")
        local configs = dap.configurations.python or {}
        local attach_fastapi, attach_flask
        for _, c in ipairs(configs) do
          if c.name:match("Attach FastAPI") then attach_fastapi = c end
          if c.name:match("Attach Flask") then attach_flask = c end
        end
        if not attach_fastapi or not attach_flask then
          vim.notify("Attach configs not found. Is .vscode/launch.json present?", vim.log.levels.WARN)
          return
        end
        -- Start FastAPI session, then attach Flask after it initializes
        dap.run(attach_fastapi)
        dap.listeners.after.event_initialized["attach_all"] = function()
          dap.listeners.after.event_initialized["attach_all"] = nil
          dap.run(attach_flask)
        end
      end, desc = "Debug all servers (attach)" },
    },
    config = function()
      local dap = require("dap")

      -- Signs
      vim.fn.sign_define("DapBreakpoint", { text = "", texthl = "DiagnosticError", linehl = "", numhl = "" })
      vim.fn.sign_define("DapBreakpointCondition", { text = "", texthl = "DiagnosticWarn", linehl = "", numhl = "" })
      vim.fn.sign_define("DapLogPoint", { text = "", texthl = "DiagnosticInfo", linehl = "", numhl = "" })
      vim.fn.sign_define("DapStopped", { text = "", texthl = "DiagnosticOk", linehl = "DapStoppedLine", numhl = "" })
      vim.fn.sign_define("DapBreakpointRejected", { text = "", texthl = "DiagnosticError", linehl = "", numhl = "" })

      -- Highlight for stopped line
      vim.api.nvim_set_hl(0, "DapStoppedLine", { default = true, link = "Visual" })

      -- VS Code accepts trailing commas; Neovim's JSON decoder does not.
      local vscode = require("dap.ext.vscode")
      local json_decode = vscode.json_decode
      vscode.json_decode = function(contents, opts)
        contents = contents
          :gsub(",%s*//[^\n]*%s*([}%]])", "%1")
          :gsub(",%s*([}%]])", "%1")
        return json_decode(contents, opts)
      end

      -- JavaScript/TypeScript configuration
      local js_debug_adapter = {
        type = "server",
        host = "localhost",
        port = "${port}",
        executable = {
          command = "node",
          args = {
            vim.fn.stdpath("data") .. "/mason/packages/js-debug-adapter/js-debug/src/dapDebugServer.js",
            "${port}",
          },
        },
      }
      for _, adapter in ipairs({ "pwa-node", "pwa-chrome", "node", "chrome" }) do
        dap.adapters[adapter] = js_debug_adapter
      end

      for _, language in ipairs({ "typescript", "javascript" }) do
        dap.configurations[language] = {
          {
            type = "pwa-node",
            request = "launch",
            name = "Launch file",
            program = "${file}",
            cwd = "${workspaceFolder}",
          },
          {
            type = "pwa-node",
            request = "attach",
            name = "Attach",
            processId = require("dap.utils").pick_process,
            cwd = "${workspaceFolder}",
          },
        }
      end

    end,
  },
}
