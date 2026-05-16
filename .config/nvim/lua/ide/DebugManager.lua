-- DebugManager: DAP debugging abstraction.
-- Internalizes nvim-dap into a clean API.
--
-- Events: 'start', 'stop', 'breakpoint'

local EventEmitter = require 'ide.EventEmitter'

local DebugManager = Class('DebugManager')
Class.include(DebugManager, EventEmitter)

function DebugManager:init()
    self._configurators = {} ---@type table<string, function>
end

--- Register a debug configurator for a project type.
---@param project_type string|string[] # project types (e.g. 'go', 'python', 'typescript')
---@param configurator function # function that sets up DAP adapters/configurations
function DebugManager:register(project_type, configurator)
    local types = type(project_type) == 'table' and project_type or { project_type }
    for _, pt in ipairs(types) do
        self._configurators[pt] = configurator
    end
end

--- Set up DAP for the current project type.
---@return boolean # whether setup succeeded
function DebugManager:setup()
    local project = IDE:project()
    local pt = project and project:type() or nil
    if not pt then return false end
    local configurator = self._configurators[pt]
    if not configurator then return false end
    configurator()
    return true
end

--- Smart start/continue: sets up DAP if needed, picks config, then runs.
function DebugManager:continue()
    local ok, dap = pcall(require, 'dap')
    if not ok then return end

    local session = dap.session()
    if session then
        dap.continue()
        self:emit('start')
        return
    end

    if not self:setup() then
        IDE.ui:error('No debugging configuration found for this project type.')
        return
    end

    local project = IDE:project()
    local pt = project and project:type() or nil
    local configs = pt and dap.configurations[pt] or {}

    if #configs == 0 then
        IDE.ui:error('No DAP configurations available.')
        return
    end

    if #configs == 1 then
        IDE.ui:info("Starting '" .. configs[1].name .. "' ...")
        dap.run(configs[1], { filetype = pt })
        self:emit('start')
        return
    end

    local dap_ui = require 'dap.ui'
    dap_ui.pick_if_many(configs, 'Configuration: ', function(c) return c.name end, function(config)
        if config then
            IDE.ui:info("Starting '" .. config.name .. "' ...")
            dap.run(config, { filetype = pt })
            self:emit('start')
        end
    end)
end

--- Stop debugging.
function DebugManager:stop()
    local ok, dap = pcall(require, 'dap')
    if ok then
        dap.terminate()
        self:emit('stop')
    end
end

--- Toggle breakpoint on the current line.
function DebugManager:toggle_breakpoint()
    local ok, dap = pcall(require, 'dap')
    if ok then
        dap.toggle_breakpoint()
        self:emit('breakpoint')
    end
end

--- Set a conditional breakpoint.
---@param condition string
function DebugManager:conditional_breakpoint(condition)
    local ok, dap = pcall(require, 'dap')
    if ok then
        dap.set_breakpoint(condition)
    end
end

--- Step over.
function DebugManager:step_over()
    local ok, dap = pcall(require, 'dap')
    if ok then dap.step_over() end
end

--- Step into.
function DebugManager:step_into()
    local ok, dap = pcall(require, 'dap')
    if ok then dap.step_into() end
end

--- Step out.
function DebugManager:step_out()
    local ok, dap = pcall(require, 'dap')
    if ok then dap.step_out() end
end

--- Get current debug status.
---@return string
function DebugManager:status()
    local ok, dap = pcall(require, 'dap')
    if ok then return dap.status() end
    return ''
end

--- Whether a debug session is active.
---@return boolean
function DebugManager:is_active()
    return self:status() ~= ''
end

--- Run to cursor position.
function DebugManager:run_to_cursor()
    local ok, dap = pcall(require, 'dap')
    if ok then dap.run_to_cursor() end
end

--- Go to line without executing intermediate code.
function DebugManager:goto_line()
    local ok, dap = pcall(require, 'dap')
    if ok then dap.goto_() end
end

--- Navigate down in the call stack.
function DebugManager:frame_down()
    local ok, dap = pcall(require, 'dap')
    if ok then dap.down() end
end

--- Navigate up in the call stack.
function DebugManager:frame_up()
    local ok, dap = pcall(require, 'dap')
    if ok then dap.up() end
end

--- Re-run the last debug configuration.
function DebugManager:run_last()
    local ok, dap = pcall(require, 'dap')
    if ok then dap.run_last() end
end

--- Pause the current debug session.
function DebugManager:pause()
    local ok, dap = pcall(require, 'dap')
    if ok then dap.pause() end
end

--- Toggle the DAP REPL.
function DebugManager:toggle_repl()
    local ok, dap = pcall(require, 'dap')
    if ok then dap.repl.toggle() end
end

--- Terminate the debug session and close the UI.
function DebugManager:terminate()
    local ok, dap = pcall(require, 'dap')
    if ok then
        dap.terminate()
        self:emit('stop')
    end
end

--- Inspect symbol under cursor (DAP widgets hover).
function DebugManager:inspect_symbol()
    local ok, widgets = pcall(require, 'dap.ui.widgets')
    if ok then widgets.hover() end
end

--- Evaluate expression (DAP UI eval).
function DebugManager:eval()
    local ok, dapui = pcall(require, 'dapui')
    if ok then dapui.eval() end
end

--- Toggle the DAP UI.
function DebugManager:toggle_ui()
    local ok, dapui = pcall(require, 'dapui')
    if ok then dapui.toggle() end
end

---@return string
function DebugManager:__tostring()
    return string.format('DebugManager(%s)', self:is_active() and 'active' or 'idle')
end

return DebugManager
