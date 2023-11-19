local utils = require 'utils'

local cache = {}

--- Creates a name for a settings table
---@param name string # the name of the setting
---@param buffer integer|nil # the buffer to create the setting for or 0 or nil for global
---@return string # the name of the settings table
local function _(name, buffer)
    assert(type(name) == 'string' and name ~= '')

    if buffer then
        name = buffer .. '_' .. name
    end

    return name
end

--- Gets a settings table
---@param name string # the name of the settings table
---@param buffer integer|nil # the buffer to get the settings for or 0 or nil for global
---@return table<string, any> # the settings table
local function get(name, buffer)
    return cache[_(name, buffer)] or {}
end

--- Sets a settings table
---@param name string # the name of the settings table
---@param buffer integer|nil # the buffer to set the settings for or 0 or nil for global
local function set(name, buffer, value)
    cache[_(name, buffer)] = value
end

-- Clear the options for a buffer
utils.on_event({ 'LspDetach', 'LspAttach', 'BufWritePost' }, function(evt)
    vim.defer_fn(utils.trigger_status_update_event, 100)
end)

utils.on_event({ 'BufDelete' }, function(evt)
    set('transient', evt.buf, nil)
    set('permanent', evt.buf, nil)
end)

utils.on_status_update_event(function(evt)
    set('transient', evt.buf, {})

    -- refresh the status showing components
    if package.loaded['lualine'] then
        local refresh = require('lualine').refresh

        ---@diagnostic disable-next-line: param-type-mismatch
        pcall(refresh)
    end
end)

---@class utils.settings
local M = {}

--- Gets a transient option for a buffer
---@param buffer integer|nil # the buffer to get the option for or 0 or nil for current
---@param option string # the name of the option
---@param default any|nil # the default value of the option
---@return any|nil # the value of the option
function M.get_transient_for_buffer(buffer, option, default)
    assert(type(option) == 'string' and option ~= '')

    buffer = buffer or vim.api.nvim_get_current_buf()

    local val = get('transient', buffer)[option]
    if val == nil then
        val = default
    end

    return val
end

--- Sets a transient option for a buffer
---@param buffer integer|nil # the buffer to set the option for or 0 or nil for current
---@param option string # the name of the option
---@param value any # the value of the option
function M.set_transient_for_buffer(buffer, option, value)
    assert(type(option) == 'string' and option ~= '')

    buffer = buffer or vim.api.nvim_get_current_buf()

    local tbl = get('transient', buffer)

    if tbl[option] ~= value then
        tbl[option] = value
        set('transient', buffer, tbl)
    end
end

local auto_transient_id = 0

--- Wraps a function to be transient option
---@param func fun(buffer: integer): any # the function to wrap
---@param option string|nil # optionla the name of the option
---@return fun(): any # the wrapped function
function M.transient(func, option)
    assert(type(func) == 'function')

    auto_transient_id = auto_transient_id + 1
    local var_name = option or ('cached_' .. tostring(auto_transient_id))

    return function()
        local buffer = vim.api.nvim_get_current_buf()
        local val = M.get_transient_for_buffer(buffer, var_name)
        if val == nil then
            val = func(buffer)
            M.set_transient_for_buffer(buffer, var_name, val)
        end

        return val
    end
end

--- Toggles a transient option for a buffer
---@param buffer integer|nil # the buffer to toggle the option for or 0 or nil for current
---@param option string # the name of the option
---@param description string|nil # the description of the option
---@param default boolean|nil # the default value of the option
---@return boolean # whether the option is enabled
function M.toggle_for_buffer(buffer, option, description, default)
    assert(type(option) == 'string' and option ~= '')

    description = description or option
    assert(type(description) == 'string' and description ~= '')

    buffer = buffer or vim.api.nvim_get_current_buf()

    if default == nil then
        default = true
    end

    local enabled = M.get_permanent_for_buffer(buffer, option, default)

    local file_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buffer), ':t')
    utils.info(string.format('Turning **%s** %s for *%s*.', enabled and 'off' or 'on', description, file_name))
    M.set_permanent_for_buffer(buffer, option, not enabled)

    return not enabled
end

--- Toggles a global option
---@param option string # the name of the option
---@param description string|nil # the description of the option
---@param default boolean|nil # the default value of the option
---@return boolean # whether the option is enabled
function M.toggle_global(option, description, default)
    assert(type(option) == 'string' and option ~= '')

    description = description or option
    assert(type(description) == 'string' and description ~= '')

    if default == nil then
        default = true
    end

    local enabled = M.get_global(option, default)

    utils.info(string.format('Turning **%s** %s *globally*.', enabled and 'off' or 'on', description))
    M.set_global(option, not enabled)

    return not enabled
end

--- Gets a toggle option for a buffer
---@param buffer integer|nil # the buffer to get the option for or 0 or nil for current
---@param option string # the name of the option
---@param default any|nil # the default value of the option
---@return boolean # whether the option is enabled
function M.get_toggle_for_buffer(buffer, option, default)
    if default == nil then
        default = true
    end

    return M.get_global(option, default) == true and M.get_permanent_for_buffer(buffer, option, default) == true
end

--- Gets a permanent option for a buffer
---@param buffer integer|nil # the buffer to get the option for or 0 or nil for current
---@param option string # the name of the option
---@param default any|nil # the default value of the option
---@return any|nil # the value of the option
function M.get_permanent_for_buffer(buffer, option, default)
    assert(type(option) == 'string' and option ~= '')

    buffer = buffer or vim.api.nvim_get_current_buf()

    local val = get('permanent', buffer)[option]
    if val == nil then
        val = default
    end

    return val
end

--- Sets a permanent option for a buffer
---@param buffer integer|nil # the buffer to set the option for or 0 or nil for current
---@param option string # the name of the option
---@param value any|nil # the value of the option
function M.set_permanent_for_buffer(buffer, option, value)
    assert(type(option) == 'string' and option ~= '')

    buffer = buffer or vim.api.nvim_get_current_buf()

    local tbl = get('permanent', buffer)

    if tbl[option] ~= value then
        tbl[option] = value
        set('permanent', buffer, tbl)

        utils.trigger_status_update_event()
    end
end

--- Gets a global option
---@param option string # the name of the option
---@param default any|nil # the default value of the option
---@return any|nil # the value of the option
function M.get_global(option, default)
    assert(type(option) == 'string' and option ~= '')

    local val = get('global')[option]
    if val == nil then
        val = default
    end

    return val
end

--- Sets a global option
---@param option string # the name of the option
---@param value any|nil # the value of the option
function M.set_global(option, value)
    assert(type(option) == 'string' and option ~= '')

    local tbl = get 'global'
    if tbl[option] ~= value then
        tbl[option] = value
        set('global', nil, tbl)

        utils.trigger_status_update_event()
    end
end

--- Gets a snapshot of the settings for a buffer
---@param buffer integer|nil # the buffer to get the settings for or 0 or nil for current
---@return table<string, table<string, any>> # the settings tables
function M.snapshot_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local settings = {
        transient = get('transient', buffer),
        permanent = get('permanent', buffer),
        global = get 'global',
    }

    return settings
end

return M
