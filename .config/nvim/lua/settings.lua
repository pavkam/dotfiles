local events = require 'events'

ide.theme.register_highlight_groups {
    NormalMenuItem = 'Special',
    SpecialMenuItem = 'Boolean',
}

---@class core.settings
local M = {}

---@type table<integer, table<string, any>>
local buffer_transient_settings = {}

local auto_transient_id = 0

--- Wraps a function to be transient option
---@param fn fun(buffer: integer): any # the function to wrap
---@param option string|nil # optional name of the option
---@return fun(): any # the wrapped function
function M.transient(fn, option)
    assert(type(fn) == 'function')

    auto_transient_id = auto_transient_id + 1
    local var_name = option or ('cached_' .. tostring(auto_transient_id))

    return function()
        local buffer = vim.api.nvim_get_current_buf()

        buffer_transient_settings[buffer] = buffer_transient_settings[buffer] or {}

        local val = buffer_transient_settings[buffer][var_name]
        if val == nil then
            val = fn(buffer)
            buffer_transient_settings[buffer] = buffer_transient_settings[buffer] or {}
            buffer_transient_settings[buffer][var_name] = val
        end

        return val
    end
end

-- Clear the options for a buffer
events.on_event({ 'LspDetach', 'LspAttach', 'BufWritePost', 'BufEnter', 'VimResized' }, function()
    vim.schedule(events.trigger_status_update_event)
end)

events.on_status_update_event(function(evt)
    buffer_transient_settings[evt.buf] = nil

    -- refresh the status showing components
    if package.loaded['lualine'] then
        local refresh = require('lualine').refresh

        ---@diagnostic disable-next-line: param-type-mismatch
        pcall(refresh)
    else
        vim.cmd.redrawstatus()
    end
end)

return M
