---@class api.config
local M = {}

---@class config_persistent_data
local persistent_data = {
    ---@type table<string, any>
    global = {},
    ---@type table<string, table<string, any>>
    file = {},
}

---@class (exact) config_update_event_data # The data for the `ConfigUpdated` event.
---@field option string # the name of the option.
---@field value any # the value of the option.
---@field buffer_id number|nil # the buffer id.

local subscribe, trigger = ide.sched.define_event 'ConfigUpdated'

-- Notifies that the configuration has been updated.
---@param args config_update_event_data # the data for the event.
local notify_config_updated = function(args)
    trigger { data = args }
end

-- Triggered when the configuration is updated.
---@param handler fun(args: { data: config_update_event_data }) # the handler for the event.
---@param opts subscribe_events_options|nil # the options for the auto command.
---@return fun() # the deregister function.
M.on_config_updated = function(handler, opts)
    return subscribe(handler, opts)
end

-- Gets the value of a config option.
---@generic T
---@param name string # the name of the option.
---@param default T # the default value of the option.
---@param buffer buffer|nil # the buffer to get the option for.
---@return T # the value of the option.
local function get(name, default, buffer)
    xassert {
        name = { name, { 'string', ['>'] = 0 } },
        buffer = { buffer, { 'nil', 'table' } },
    }

    if buffer then
        if not buffer.is_normal then
            return default
        end

        local v = vim.b[buffer.id][name]
        if v == nil then
            v = default
        end

        return v
    else
        local v = vim.g[name]
        if v == nil then
            v = persistent_data.global[name]
        end
        if v == nil then
            v = default
        end
        return v
    end
end

-- Sets the value of a config option.
---@generic T
---@param name string # the name of the option.
---@param persistent boolean # whether the option is persistent or not.
---@param value T # the value of the option.
---@param buffer buffer|nil # the buffer to set the option for.
local function set(name, persistent, value, buffer)
    if buffer then
        if not buffer.is_normal then
            return
        end

        vim.b[buffer.id][name] = value
        if persistent and buffer.file_path then
            persistent_data.file[buffer.file_path] = persistent_data.file[buffer.file_path] or {}
            persistent_data.file[buffer.file_path][name] = value
        end
    else
        vim.g[name] = value
        if persistent then
            persistent_data.global[name] = value
        end
    end

    notify_config_updated {
        option = name,
        value = value,
        buffer_id = buffer and buffer.id,
    }
end

---@class (exact) config_option # A subscription to a config option.
---@field get fun(default: any|nil): any # gets the value of the option.
---@field set fun(value: any) # sets the value of the option.

---@class (exact) config_use_options # Options for subscribing to a config option.
---@field buffer buffer|nil # the buffer to subscribe to.
---@field persistent boolean|nil # whether the option is persistent or not.

-- Use a config option.
---@param name string # the name of the option.
---@param opts config_use_options # the options.
---@return config_option # the config option.
function M.use(name, opts)
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

    if opts.buffer and not opts.buffer.is_normal then
        error(string.format('buffer `%s` is not normal or valid', opts.buffer.id))
    end

    local option = {
        get = function(default)
            return get(name, default, opts.buffer)
        end,
        set = function(value)
            set(name, opts.persistent, value, opts.buffer)
        end,
    }

    return table.freeze(option)
end

---@alias config_toggle_scope 'buffer' | 'global' # the scope of the toggle

---@class (exact) config_toggle_details # A toggle.
---@field name string # the name of the option.
---@field desc string # the description of the option.
---@field value_fn fun(buffer: buffer|nil): boolean # the function to get the value of the option.
---@field toggle_fn fun(buffer: buffer|nil) # the function to toggle the option.
---@field scope config_toggle_scope # the scope of the option.

---@type config_toggle_details[]
local managed_toggles = {}

---@class (exact) config_register_toggle_options # The options for registering a toggle.
---@field desc string|nil # the description of the option (defaults to the name).
---@field icon string|nil # the icon of the option.
---@field scope config_toggle_scope|config_toggle_scope[]|nil # the scope of the option.
---@field default boolean|nil # the default value of the option.

-- Registers a managed toggle setting.
---@param name string # the name of the option.
---@param toggle_fn fun(enabled: boolean, buffer: buffer|nil) # the function to call when the toggle is triggered.
---@param opts config_register_toggle_options|nil # the options for the toggle.
---@return config_toggle # the config option.
function M.register_toggle(name, toggle_fn, opts)
    local icons = require 'icons'

    ---@type config_register_toggle_options
    opts = table.merge(opts, {
        scope = 'global',
        icon = icons.UI.Tool,
        default = true,
    })

    xassert {
        name = { name, { 'string', ['>'] = 0 } },
        toggle_fn = { toggle_fn, 'callable' },
        opts = {
            opts,
            {
                desc = { 'nil', { 'string', ['>'] = 0 } },
                icon = { 'string' },
                scope = {
                    { 'string', ['*'] = '^global|buffer$' },
                    {
                        'list',
                        ['*'] = {
                            'string',
                            ['*'] = '^global|buffer$',
                        },
                    },
                },
                default = { 'boolean' },
            },
        },
    }

    local scopes = table.to_list(opts.scope)

    for _, scope in ipairs(scopes) do
        local get_value = scope == 'buffer'
                and function(buffer)
                    return get(name, opts.default, buffer)
                end
            or function()
                return get(name, opts.default)
            end

        ---@param buffer buffer|nil
        local toggle_value = function(buffer)
            if buffer and not buffer.is_normal then
                return
            end

            local enabled = get_value(buffer)

            if buffer ~= nil then
                local file_name = ide.fs.base_name(buffer.file_path)
                ide.tui.hint(
                    string.format(
                        'Turning **%s** `%s` for `%s`.',
                        enabled and 'off' or 'on',
                        icons.iconify(opts.icon, opts.desc),
                        file_name
                    ),
                    { prefix_icon = icons.UI.Toggle }
                )
            else
                ide.tui.hint(
                    string.format(
                        'Turning **%s** `%s` globally.',
                        enabled and 'off' or 'on',
                        icons.iconify(opts.icon, opts.desc)
                    ),
                    { prefix_icon = icons.UI.Toggle }
                )
            end

            enabled = not enabled
            set(name, true, enabled, scope == 'buffer' and buffer or nil)

            if scope == 'global' then
                toggle_fn(enabled, nil)

                if vim.tbl_contains(scopes, 'buffer') then
                    for _, b in ipairs(ide.buf) do
                        if b.is_normal then
                            toggle_fn(enabled and get(name, opts.default --[[@as boolean]], b), b)
                        end
                    end
                end
            elseif scope == 'buffer' then
                toggle_fn(enabled and get(name, opts.default --[[@as boolean]]), buffer)
            else
                assert(false)
            end
        end

        table.insert(managed_toggles, {
            name = name,
            desc = opts.desc or name,
            toggle_fn = toggle_value,
            value_fn = get_value,
            scope = scope,
        })
    end

    return M.use_toggle(name)
end

---@class (exact) config_toggle # A toggle.
---@field get fun(buffer: buffer|nil): boolean # gets the value of the toggle.
---@field set fun(value: boolean|nil, buffer: buffer|nil) # sets the value of the toggle.

-- Use a config option.
---@param name string # the name of the option.
---@return config_toggle # the config option.
function M.use_toggle(name)
    xassert {
        name = { name, { 'string', ['>'] = 0 } },
    }

    local toggles = table.list_filter(managed_toggles, function(toggle)
        return toggle.name == name
    end)

    if #toggles == 0 then
        error(string.format('toggle `%s` not found', name))
    end

    assert(#toggles <= 2)

    local global_toggle = toggles[1].scope == 'global' and toggles[1] or toggles[2]
    local buffer_toggle = toggles[1].scope == 'buffer' and toggles[1] or toggles[2]

    if global_toggle and buffer_toggle then
        return table.freeze {
            get = function(buffer)
                xassert {
                    buffer = { buffer, { 'table' } },
                }

                return global_toggle.value_fn() and buffer_toggle.value_fn(buffer)
            end,
            set = function(value, buffer)
                xassert {
                    buffer = { buffer, { 'nil', 'table' } },
                }

                if buffer and buffer_toggle.value_fn(buffer) ~= value then
                    buffer_toggle.toggle_fn(buffer)
                elseif not buffer and global_toggle.value_fn() ~= value then
                    global_toggle.toggle_fn(buffer)
                end
            end,
        }
    elseif global_toggle then
        return table.freeze {
            get = function()
                return global_toggle.value_fn()
            end,
            set = function(value)
                if value == nil or global_toggle.value_fn() ~= value then
                    global_toggle.toggle_fn()
                end
            end,
        }
    else
        return table.freeze {
            get = function(buffer)
                xassert {
                    buffer = { buffer, 'table' },
                }

                return buffer_toggle.value_fn(buffer)
            end,
            set = function(value, buffer)
                xassert {
                    buffer = { buffer, 'table' },
                }

                if buffer_toggle.value_fn(buffer) ~= value then
                    buffer_toggle.toggle_fn(buffer)
                end
            end,
        }
    end
end

--- Exports the configuration settings.
---@return config_persistent_data # the settings.
function M.export()
    return table.clone(persistent_data)
end

--- Restores the configuration settings.
---@param data config_persistent_data # the settings to restore.
function M.import(data)
    xassert {
        data = { data, { global = 'table', file = 'table' } },
    }

    for option, value in pairs(data.global) do
        vim.g[option] = value
        notify_config_updated {
            option = option,
            value = value,
        }
    end

    for file_path, options in pairs(data.file) do
        local buffer = ide.buf[vim.fn.bufnr(file_path)]

        if buffer and buffer.is_loaded then
            for option, value in pairs(options) do
                vim.b[buffer.id][option] = value
                notify_config_updated {
                    option = option,
                    value = value,
                    buffer_id = buffer.id,
                }
            end
        end
    end

    persistent_data = data
end

-- Manages the toggles.
---@param buffer buffer|nil # the buffer to show toggles for.
function M.manage(buffer)
    buffer = buffer or ide.buf.current --[[@as buffer]]
    xassert {
        buffer = { buffer, { 'table' } },
    }

    local sorted = table.list_sort(managed_toggles, function(a, b)
        if a.name == b.name then
            return a.scope < b.scope
        else
            return a.name < b.name
        end
    end)

    local entries = table.list_map(sorted, function(item)
        return table.merge(item, {
            status = item.value_fn(item.scope == 'buffer' and buffer or nil) and 'on' or 'off',
        })
    end)

    ide.tui.select(entries, {
        { 'desc', prio = 1 },
        { 'scope', prio = 2 },
        { 'status' },
    }, function(item)
        if item.scope == 'buffer' then
            item.toggle_fn(buffer)
        else
            item.toggle_fn()
        end
    end, {
        prompt = 'Toggle an option',
        highlighter = function(item, col)
            if col == 'desc' or col == 'scope' then
                if item.scope == 'buffer' then
                    return 'NormalMenuItem'
                else
                    return 'SpecialMenuItem'
                end
            else
                local value = item.value_fn(item.scope == 'buffer' and buffer or nil)
                if value then
                    return 'DiagnosticOk'
                else
                    return 'DiagnosticError'
                end
            end
        end,
    })
end

ide.sched.subscribe_event('BufReadPost', function(args)
    local buffer = assert(ide.buf[args.buf])

    ---@type table<string, any>
    local options = persistent_data.file[buffer.file_path]
    if options then
        for option, value in pairs(options) do
            vim.b[buffer.id][option] = value
            notify_config_updated {
                option = option,
                value = value,
                buffer_id = buffer.id,
            }
        end
    end
end, {
    description = 'Triggers when a buffer is read and the config needs to be updated.',
    group = 'config.apply_buffer_config',
})

return table.freeze(M)
