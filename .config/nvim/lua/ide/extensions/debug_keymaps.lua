-- Debug keymaps extension: DAP keybindings and language configurator registration.
-- Replaces legacy debugging.lua.

local Extension = require 'ide.Extension'

local DebugKeymaps = Class('DebugKeymaps', Extension)

function DebugKeymaps:init()
    Extension.init(self, 'DebugKeymaps')
end

function DebugKeymaps:on_register(ctx)
    -- Register language debug configurators
    local function safe_require(mod)
        return function() require(mod)() end
    end

    IDE.debug:register('go', safe_require('ide.extensions.debug_configs.go'))
    IDE.debug:register('python', safe_require('ide.extensions.debug_configs.python'))
    IDE.debug:register({ 'javascript', 'typescript', 'javascriptreact', 'typescriptreact' }, safe_require('ide.extensions.debug_configs.js'))

    -- Key group
    if IDE.keys and IDE.keys.group then
        IDE.keys:group('<leader>d', { desc = 'Debugger', mode = { 'n', 'v' } })
    end

    -- Debug keymaps
    ctx:keymap('n', '<leader>dc', function() IDE.debug:continue() end, { desc = 'Continue/Start' })
    ctx:keymap('n', '<leader>ds', function() IDE.debug:stop() end, { desc = 'Stop' })
    ctx:keymap('n', '<leader>db', function() IDE.debug:toggle_breakpoint() end, { desc = 'Toggle breakpoint' })
    ctx:keymap('n', '<leader>dB', function()
        IDE.ui:input('Condition: ', function(cond)
            if cond and cond ~= '' then IDE.debug:conditional_breakpoint(cond) end
        end)
    end, { desc = 'Conditional breakpoint' })
    ctx:keymap('n', '<leader>do', function() IDE.debug:step_over() end, { desc = 'Step over' })
    ctx:keymap('n', '<leader>di', function() IDE.debug:step_into() end, { desc = 'Step into' })
    ctx:keymap('n', '<leader>dO', function() IDE.debug:step_out() end, { desc = 'Step out' })
    ctx:keymap('n', '<leader>du', function() IDE.debug:toggle_ui() end, { desc = 'Toggle DAP UI' })
    ctx:keymap('n', '<leader>dC', function() IDE.debug:run_to_cursor() end, { desc = 'Run to cursor' })
    ctx:keymap('n', '<leader>dg', function() IDE.debug:goto_line() end, { desc = 'Go to line (no execute)' })
    ctx:keymap('n', '<leader>dj', function() IDE.debug:frame_down() end, { desc = 'Stack frame down' })
    ctx:keymap('n', '<leader>dk', function() IDE.debug:frame_up() end, { desc = 'Stack frame up' })
    ctx:keymap('n', '<leader>dl', function() IDE.debug:run_last() end, { desc = 'Run last' })
    ctx:keymap('n', '<leader>dP', function() IDE.debug:pause() end, { desc = 'Pause' })
    ctx:keymap('n', '<leader>dR', function() IDE.debug:toggle_repl() end, { desc = 'Toggle REPL' })
    ctx:keymap('n', '<leader>dQ', function() IDE.debug:terminate() end, { desc = 'Terminate' })
    ctx:keymap('n', '<leader>dw', function() IDE.debug:inspect_symbol() end, { desc = 'Inspect symbol' })
    ctx:keymap({ 'n', 'v' }, '<leader>de', function() IDE.debug:eval() end, { desc = 'Evaluate expression' })
end

return DebugKeymaps
