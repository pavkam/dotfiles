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

-- Clear the transient options for a buffer
utils.on_event({ 'LspDetach', 'LspAttach', 'BufWritePost' }, function(evt)
    set('transient', evt.buf, {})
end)

utils.on_event({ 'BufDelete' }, function(evt)
    set('transient', evt.buf, nil)
    set('permanent', evt.buf, nil)
end)

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
    tbl[option] = value

    set('transient', buffer, tbl)
end

local auto_transient_id = 0

--- Wraps a function to be transient option
---@param func fun(buffer: integer): any # the function to wrap
---@param option string|nil # optionla the name of the option
---@return fun(buffer: integer): any # the wrapped function
function M.transient(func, option)
    assert(type(func) == 'function')

    auto_transient_id = auto_transient_id + 1
    local var_name = option or tostring(auto_transient_id)

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

    tbl[utils.stringify(option)] = value

    set('permanent', buffer, tbl)
end

--- Gets a global option
---@param option string # the name of the option
---@param default any|nil # the default value of the option
---@return any|nil # the value of the option
function M.get_global(option, default)
    assert(type(option) == 'string' and option ~= '')

    local val = get('global')[utils.stringify(option)]
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
    tbl[utils.stringify(option)] = value

    set('global', nil, tbl)
end

vim.api.nvim_create_user_command('DebugBufferSettings', function()
    local lsp = require 'utils.lsp'
    local project = require 'utils.project'

    local buffer = vim.api.nvim_get_current_buf()
    local settings = {
        project = {
            lsp_roots = lsp.roots(buffer),
            roots = project.roots(buffer),
            type = project.type(buffer),
        },
        transient = get('transient', buffer),
        permanent = get('permanent', buffer),
        global = get 'global',
    }

    require('noice').redirect(function()
        print(vim.inspect(settings))
    end)
end, { desc = 'Run Lazygit', nargs = 0 })

return M
