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
utils.on_event({ 'LspDetach', 'LspAttach', 'BufWritePost', 'BufEnter' }, function()
    vim.defer_fn(utils.trigger_status_update_event, 100)
end)

utils.on_event('BufDelete', function(evt)
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
        local val = M.get(var_name, { buffer = buffer, transient = true })
        if val == nil then
            val = func(buffer)
            M.set(var_name, val, { buffer = buffer, transient = true })
        end

        return val
    end
end

--- Changes the value of an option
---@param option string # the name of the option
---@param value any|nil # the value of the option
---@param opts? { buffer?: integer, transient?: boolean } # optional options
function M.set(option, value, opts)
    assert(type(option) == 'string' and option ~= '')

    opts = opts or {}

    if opts.buffer == nil then
        local tbl = get 'global'
        if tbl[option] ~= value then
            tbl[option] = value
            set('global', nil, tbl)
        end
    else
        local buffer = opts.buffer or vim.api.nvim_get_current_buf()
        local key = opts.transient and 'transient' or 'permanent'

        local tbl = get(key, buffer)

        if tbl[option] ~= value then
            tbl[option] = value
            set(key, buffer, tbl)
        end
    end

    if not opts.transient then
        utils.trigger_status_update_event()
    end
end

--- Gets a global option
---@param option string # the name of the option
---@param opts? { buffer?: integer, transient?: boolean, default?: any } # optional options
---@return any|nil # the value of the option
function M.get(option, opts)
    assert(type(option) == 'string' and option ~= '')

    opts = opts or {}

    local val
    if opts.buffer == nil then
        val = get('global')[option]
    else
        local buffer = opts.buffer or vim.api.nvim_get_current_buf()
        local key = opts.transient and 'transient' or 'permanent'

        val = get(key, buffer)[option]
    end

    if val == nil then
        val = opts.default
    end

    return val
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

--- Gets the global settings
---@class utils.settings.GlobalSettings
---@field auto_formatting_enabled boolean # whether auto-formatting is enabled
---@field auto_linting_enabled boolean # whether auto-linting is enabled
---@field ignore_hidden_files boolean # whether hidden files should be hidden
M.global = setmetatable({}, {
    __index = function(_, key)
        return M.get(key, { default = true })
    end,
    __newindex = function(_, key, value)
        M.set(key, value)
    end,
})

---@class utils.settings.BufferSettings
---@field auto_formatting_enabled boolean # whether auto-formatting is enabled
---@field auto_linting_enabled boolean # whether auto-linting is enabled

--- Gets the settings for a buffer
---@type utils.settings.BufferSettings[]
M.buf = setmetatable({}, {
    __index = function(_, buffer)
        assert(type(buffer) == 'number' and buffer >= 0)

        return setmetatable({}, {
            __index = function(_, key)
                return M.get(key, { buffer = buffer, default = true })
            end,
            __newindex = function(_, key, value)
                M.set(key, value, { buffer = buffer })
            end,
        })
    end,
})

return M
