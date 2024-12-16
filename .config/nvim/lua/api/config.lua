---@class api.config
local M = {}

---@module 'api.buf'

---@class config_persistent_data
local persistent_data = {
    ---@type table<string, any>
    global = {},
    ---@type table<string, table<string, any>>
    file = {},
}

local observers = {
    ---@type table<string, table<fun(value: any), boolean>>
    global = {},
    ---@type table<string, table<integer, table<fun(value: any), boolean>>>
    buffer = {},
}

-- Trigger observers for a config option.
---@param name string # the name of the option.
---@param value any # the new value of the option.
---@param buffer buffer|nil # the buffer to trigger the observers for.
local function trigger_observers(name, value, buffer)
    xassert {
        name = { name, { 'string', ['>'] = 0 } },
        buffer = { buffer, { 'nil', 'table' } },
    }

    if not buffer then
        local global_observers = observers.global[name]
        if global_observers then
            for observer in global_observers do
                observer(value) --TODO: pcall
            end
        end

        local buffer_observers = observers.buffer[name]
        if buffer_observers then
            for _, in_observers in pairs(buffer_observers) do
                for observer in in_observers do
                    observer(value) --TODO: pcall
                end
            end
        end
    else
        local buffer_observers = observers.buffer[name]
        if buffer_observers then
            local in_observers = buffer_observers[buffer.id]

            if in_observers then
                for observer in in_observers do
                    observer(value) --TODO: pcall
                end
            end
        end
    end
end

---@class (exact) config_option # A subscription to a config option.
---@field get fun(default: any|nil): any # gets the value of the option.
---@field set fun(value: any) # sets the value of the option.
---@field observe fun(callback: fun(value: any)): config_option # add observer to the option.

---@class (exact) config_subscribe_options # Options for subscribing to a config option.
---@field buffer buffer|nil # the buffer to subscribe to.
---@field persistent boolean|nil # whether the option is persistent or not.

-- Subscribe to a config option.
---@param name string # the name of the option.
---@param opts config_subscribe_options # the options for subscribing to the option.
---@return config_option # the subscription to the option.
function M.subscribe(name, opts)
    opts = table.merge(opts, { persistent = true })
    xassert {
        name = { name, { 'string', ['>'] = 0 } },
        opts = {
            opts,
            {
                buffer = { 'nil', 'table' },
                persistent = 'boolean',
            },
        },
    }

    local option = {}

    option.get = opts.buffer
            and function(default)
                if not opts.buffer.is_valid then
                    return default
                end

                return vim.b[opts.buffer.id][name] or default
            end
        or function(default)
            return vim.v[name] or persistent_data.global[name] or default
        end
    option.set = opts.buffer
            and function(value)
                if not opts.buffer.is_valid then
                    return
                end

                vim.b[opts.buffer.id][name] = value
                if opts.persistent then
                    persistent_data.file[opts.buffer.file_path][name] = value
                end

                trigger_observers(name, value, opts.buffer)
            end
        or function(value)
            vim.v[name] = value
            if opts.persistent then
                persistent_data.global[name] = value
            end

            trigger_observers(name, value)
        end

    option.observe = function(callback)
        xassert {
            callback = { callback, 'callable' },
        }

        if opts.buffer then
            observers.buffer[name] = observers.buffer[name] or {}
            observers.buffer[name][opts.buffer.id] = observers.buffer[name][opts.buffer.id] or table.weak {}
            observers.buffer[name][opts.buffer.id][callback] = true
        else
            observers.global[name] = observers.global[name] or table.weak {}
            observers.global[name][callback] = true
        end

        return option
    end

    return table.freeze(option)
end

--- Exports the settings to JSON.
---@return string # the JSON representation of the settings.
function M.to_json()
    return vim.json.encode(persistent_data)
end

--- Restores settings from a JSON string.
---@param json string # the JSON representation of the settings.
---@return boolean # true if the settings were restored successfully, false otherwise.
function M.from_json(json)
    xassert {
        json = { json, { 'string', ['>'] = 0 } },
    }

    ---@type boolean, config_persistent_data
    local ok, data = pcall(vim.json.decode, json)
    if not ok then
        return false
    end

    local _, ty = xtype(data)
    if ty ~= 'table' then
        return false
    end

    _, ty = xtype(data.global)
    if ty ~= 'table' then
        return false
    end

    _, ty = xtype(data.file)
    if ty ~= 'table' then
        return false
    end

    persistent_data = data

    for name, value in pairs(persistent_data.global) do
        vim.v[name] = value
        trigger_observers(name, value)
    end

    for file_path, options in pairs(persistent_data.file) do
        local buffer = require('api.buf')[vim.fn.bufnr(file_path)]

        if buffer and buffer.is_loaded then
            for option, value in pairs(options) do
                vim.b[buffer.id][option] = value
                trigger_observers(option, value, buffer)
            end
        end
    end

    return true
end

local auto_group = vim.api.nvim_create_augroup('config.load_config_for_restored_buffers', { clear = true })
vim.api.nvim_create_autocmd('BufReadPost', {
    group = auto_group,
    callback = function(evt)
        local buffer = require('api.buf')[evt.buf]
        local options = persistent_data.file[buffer.file_path]
        if options then
            for option, value in pairs(options) do
                vim.b[evt.buf][option] = value
                trigger_observers(option, value, buffer)
            end
        end
    end,
})

return M
