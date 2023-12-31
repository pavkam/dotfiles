local utils = require 'core.utils'

---@type table<string, any>
local global_settings = {}
---@type table<integer, any>
local permanent_settings = {}
---@type table<integer, any>
local instance_settings = {}
---@type table<integer, any>
local transient_settings = {}

-- Clear the options for a buffer
utils.on_event({ 'LspDetach', 'LspAttach', 'BufWritePost', 'BufEnter', 'VimResized' }, function()
    vim.defer_fn(utils.trigger_status_update_event, 100)
end)

utils.on_event('BufDelete', function(evt)
    transient_settings[evt.buf] = nil
    instance_settings[evt.buf] = nil
end)

utils.on_status_update_event(function(evt)
    transient_settings[evt.buf] = nil

    -- refresh the status showing components
    if package.loaded['lualine'] then
        local refresh = require('lualine').refresh

        ---@diagnostic disable-next-line: param-type-mismatch
        pcall(refresh)
    end
end)

---@class core.settings
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
        local val = M.get(var_name, { buffer = buffer, scope = 'transient' })
        if val == nil then
            val = func(buffer)
            M.set(var_name, val, { buffer = buffer, scope = 'transient' })
        end

        return val
    end
end

---@alias core.settings.Scope 'transient' | 'permanent' | 'instance' | 'global'

--- Changes the value of an option
---@param option string # the name of the option
---@param value any|nil # the value of the option
---@param opts? { buffer?: integer, scope: core.settings.Scope } # optional options
function M.set(option, value, opts)
    assert(type(option) == 'string' and option ~= '')
    opts = opts or {}
    assert(opts.scope == nil or opts.scope == 'transient' or opts.scope == 'permanent' or opts.scope == 'instance' or opts.scope == 'global')

    if opts.scope == 'global' then
        if global_settings[option] ~= value then
            global_settings[option] = value
        end
    else
        opts.buffer = opts.buffer or vim.api.nvim_get_current_buf()
        if opts.scope == 'instance' then
            if not instance_settings[opts.buffer] then
                instance_settings[opts.buffer] = {}
            end
            instance_settings[opts.buffer][option] = value
        elseif opts.scope == 'transient' then
            if not transient_settings[opts.buffer] then
                transient_settings[opts.buffer] = {}
            end
            transient_settings[opts.buffer][option] = value
        elseif opts.scope == 'permanent' then
            if not permanent_settings[opts.buffer] then
                permanent_settings[opts.buffer] = {}
            end
            permanent_settings[opts.buffer][option] = value
        end
    end
    --
    -- if opts.scope ~= 'transient' then
    --     utils.trigger_status_update_event()
    -- end
end

--- Gets a global option
---@param option string # the name of the option
---@param opts? { buffer?: integer, scope: core.settings.Scope , default?: any } # optional options
---@return any|nil # the value of the option
function M.get(option, opts)
    assert(type(option) == 'string' and option ~= '')
    opts = opts or {}
    assert(opts.scope == nil or opts.scope == 'transient' or opts.scope == 'permanent' or opts.scope == 'instance' or opts.scope == 'global')

    local val
    if opts.scope == 'global' then
        val = global_settings[option]
    else
        local buffer = opts.buffer or vim.api.nvim_get_current_buf()
        if opts.scope == 'transient' then
            val = transient_settings[buffer] and transient_settings[buffer][option]
        elseif opts.scope == 'instance' then
            val = instance_settings[buffer] and instance_settings[buffer][option]
        elseif opts.scope == 'permanent' then
            val = permanent_settings[buffer] and permanent_settings[buffer][option]
        end
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
        transient = transient_settings[buffer],
        permanent = permanent_settings[buffer],
        instance = instance_settings[buffer],
        global = global_settings,
    }

    return settings
end

--- Gets a snapshot of all settings
---@return { global: table<string, any>, files: table<string, any> } # the settings tables
function M.snapshot()
    local buf_opts = {}
    for buffer, settings in pairs(permanent_settings) do
        buf_opts[vim.api.nvim_buf_get_name(buffer)] = settings
    end

    local settings = {
        global = global_settings,
        files = buf_opts,
    }

    return settings
end

--- Gets the global settings
---@class core.settings.GlobalSettings
---@field auto_formatting_enabled boolean # whether auto-formatting is enabled
---@field auto_linting_enabled boolean # whether auto-linting is enabled
---@field ignore_hidden_files boolean # whether hidden files should be hidden
M.global = setmetatable({}, {
    __index = function(_, key)
        return M.get(key, { default = true, scope = 'global' })
    end,
    __newindex = function(_, key, value)
        M.set(key, value, { scope = 'global' })
    end,
})

---@class core.settings.BufferSettings
---@field auto_formatting_enabled boolean # whether auto-formatting is enabled
---@field auto_linting_enabled boolean # whether auto-linting is enabled

--- Gets the settings for a buffer
---@type core.settings.BufferSettings[]
M.buf = setmetatable({}, {
    __index = function(_, buffer)
        assert(type(buffer) == 'number' and buffer >= 0)

        return setmetatable({}, {
            __index = function(_, key)
                return M.get(key, { buffer = buffer, default = true, scope = 'permanent' })
            end,
            __newindex = function(_, key, value)
                M.set(key, value, { buffer = buffer, scope = 'permanent' })
            end,
        })
    end,
})

return M
