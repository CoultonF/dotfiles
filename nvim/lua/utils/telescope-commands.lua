-- Context-aware project commands for Telescope
local M = {}

local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local conf = require('telescope.config').values

-- Detect if we're in the rcom project (works both locally and in devpod)
local function get_project_root()
  local cwd = vim.fn.getcwd()
  
  -- Check if we're in devpod (/project)
  if cwd:match("^/project") then
    return "/project"
  end
  
  -- Check if we're in local rcom
  if cwd:match("rcom") then
    local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
    if vim.v.shell_error == 0 then
      return git_root
    end
  end
  
  return nil
end

-- Get context-aware commands based on current directory
local function get_project_commands()
  local root = get_project_root()
  if not root then
    return {}
  end
  
  local cwd = vim.fn.getcwd()
  local commands = {}
  
  -- Always available commands
  table.insert(commands, { name = '🚀 Start Dev Servers', cmd = 'bash ' .. root .. '/scripts/dev-servers.sh start' })
  table.insert(commands, { name = '🛑 Stop Dev Servers', cmd = 'bash ' .. root .. '/scripts/dev-servers.sh stop' })
  table.insert(commands, { name = '🔄 Restart Dev Servers', cmd = 'bash ' .. root .. '/scripts/dev-servers.sh restart' })
  table.insert(commands, { name = '📊 Dev Servers Status', cmd = 'bash ' .. root .. '/scripts/dev-servers.sh status' })
  table.insert(commands, { name = '📝 Dev Servers Logs', cmd = 'bash ' .. root .. '/scripts/dev-servers.sh logs' })
  table.insert(commands, { name = '🔑 Set Redis Session', cmd = 'cd ' .. root .. '/flask_app && .venv/bin/python ' .. root .. '/scripts/set_redis_session.py' })
  table.insert(commands, { name = '🧪 Run All Tests', cmd = 'bash ' .. root .. '/scripts/run_all_tests_comprehensive.sh' })
  
  -- Context-specific commands based on subdirectory
  if cwd:match("flask_app") or cwd:match("flask%-app") then
    table.insert(commands, { name = '🐍 Activate Flask venv', cmd = 'source ' .. root .. '/flask_app/.venv/bin/activate' })
    table.insert(commands, { name = '🧪 Flask Tests', cmd = 'cd ' .. root .. '/flask_app && pytest' })
    table.insert(commands, { name = '🔍 Ruff Check Flask', cmd = 'cd ' .. root .. '/flask_app && ruff check --fix .' })
    table.insert(commands, { name = '🎨 Ruff Format Flask', cmd = 'cd ' .. root .. '/flask_app && ruff format .' })
  end
  
  if cwd:match("fast_api") or cwd:match("fast%-api") then
    table.insert(commands, { name = '🐍 Activate FastAPI venv', cmd = 'source ' .. root .. '/fast_api/.venv/bin/activate' })
    table.insert(commands, { name = '🧪 FastAPI Tests', cmd = 'cd ' .. root .. '/fast_api && pytest' })
    table.insert(commands, { name = '🔍 Ruff Check FastAPI', cmd = 'cd ' .. root .. '/fast_api && ruff check --fix .' })
    table.insert(commands, { name = '🎨 Ruff Format FastAPI', cmd = 'cd ' .. root .. '/fast_api && ruff format .' })
  end
  
  if cwd:match("react") then
    table.insert(commands, { name = '⚛️  Build React', cmd = 'cd ' .. root .. '/flask_app/app/inertia/react && bun run build' })
    table.insert(commands, { name = '🔍 TypeScript Check', cmd = 'cd ' .. root .. '/flask_app/app/inertia/react && bun run tsc' })
    table.insert(commands, { name = '🎨 Lint React', cmd = 'cd ' .. root .. '/flask_app/app/inertia/react && bun run lint' })
    table.insert(commands, { name = '📦 Generate Types', cmd = 'cd ' .. root .. '/flask_app/app/inertia/react && bun run generate-types' })
  end
  
  if cwd:match("packages") then
    table.insert(commands, { name = '🔧 Install Packages', cmd = 'cd ' .. root .. '/packages && pip install -e .' })
  end
  
  return commands
end

-- Show all project commands
function M.show_commands()
  local commands = get_project_commands()
  
  if #commands == 0 then
    vim.notify("Not in rcom project", vim.log.levels.WARN)
    return
  end
  
  pickers.new({}, {
    prompt_title = 'Project Commands (' .. vim.fn.fnamemodify(vim.fn.getcwd(), ':t') .. ')',
    finder = finders.new_table({
      results = commands,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.name,
          ordinal = entry.name,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        -- Open in terminal split
        vim.cmd('split | terminal ' .. selection.value.cmd)
      end)
      return true
    end,
  }):find()
end

-- Quick dev servers picker (just server commands)
function M.dev_servers()
  local root = get_project_root()
  if not root then
    vim.notify("Not in rcom project", vim.log.levels.WARN)
    return
  end
  
  local commands = {
    { name = '🚀 Start Dev Servers', cmd = 'bash ' .. root .. '/scripts/dev-servers.sh start' },
    { name = '🛑 Stop Dev Servers', cmd = 'bash ' .. root .. '/scripts/dev-servers.sh stop' },
    { name = '🔄 Restart Dev Servers', cmd = 'bash ' .. root .. '/scripts/dev-servers.sh restart' },
    { name = '📊 Dev Servers Status', cmd = 'bash ' .. root .. '/scripts/dev-servers.sh status' },
    { name = '📝 Dev Servers Logs', cmd = 'bash ' .. root .. '/scripts/dev-servers.sh logs' },
  }
  
  pickers.new({}, {
    prompt_title = 'Dev Servers',
    finder = finders.new_table({
      results = commands,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.name,
          ordinal = entry.name,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        vim.cmd('split | terminal ' .. selection.value.cmd)
      end)
      return true
    end,
  }):find()
end

return M
