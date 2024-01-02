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
    permanent_settings[evt.buf] = nil
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
---@param opts? { buffer?: integer, scope?: core.settings.Scope } # optional options
function M.set(option, value, opts)
    assert(type(option) == 'string' and option ~= '')
    opts = opts or {}

    if not opts.scope then
        opts.scope = opts.buffer and 'permanent' or 'global'
    end

    assert(opts.scope == 'transient' or opts.scope == 'permanent' or opts.scope == 'instance' or opts.scope == 'global')

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
---@param opts? { buffer?: integer, default?: any, scope?: core.settings.Scope } # optional options
---@return any|nil # the value of the option
function M.get(option, opts)
    assert(type(option) == 'string' and option ~= '')

    opts = opts or {}

    if not opts.scope then
        opts.scope = opts.buffer and 'permanent' or 'global'
    end

    assert(opts.scope == 'transient' or opts.scope == 'permanent' or opts.scope == 'instance' or opts.scope == 'global')

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

--- Toggles a permanent buffer or global boolean option
---@param option string # the name of the option
---@param opts? { buffer?: integer, description?: string, default?: boolean } # optional modifiers
---@return boolean # whether the option is enabled
function M.toggle(option, opts)
    assert(type(option) == 'string' and option ~= '')

    opts = opts or {}
    opts.description = opts.description or option
    assert(type(opts.description) == 'string' and opts.description ~= '')

    local enabled = M.get(option, { buffer = opts.buffer, default = opts.default })

    if opts.buffer ~= nil then
        local file_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(opts.buffer), ':t')
        utils.info(string.format('Turning **%s** %s for *%s*.', enabled and 'off' or 'on', opts.description, file_name))
    else
        utils.info(string.format('Turning **%s** %s *globally*.', enabled and 'off' or 'on', opts.description))
    end

    M.set(option, not enabled, { buffer = opts.buffer })

    return not enabled
end

---@alias core.settings.ToggleScope 'buffer' | 'global'

---@class core.settings.RegistryItem
---@field name string
---@field value_fn fun(buffer?: integer): boolean
---@field toggle_fn fun(buffer?: integer)
---@field scope core.settings.ToggleScope

---@type core.settings.RegistryItem[]
local registry = {}

--- Registers a toggle
---@param name string # the name of the toggle
---@param scopes core.settings.ToggleScope[] # the scope(s) of the toggle
---@param value_fn fun(buffer?: integer): boolean # the function to call to get the current value of the toggle
---@param toggle_fn fun(buffer?: integer) # the function to call when the toggle is triggered
local function register(name, scopes, value_fn, toggle_fn)
    assert(type(name) == 'string' and name ~= '')
    assert(type(toggle_fn) == 'function')
    assert(type(value_fn) == 'function')

    assert(vim.tbl_islist(scopes))

    for _, scope in ipairs(scopes) do
        assert(scope == 'buffer' or scope == 'global')

        registry[#registry + 1] = {
            name = name,
            toggle_fn = toggle_fn,
            value_fn = value_fn,
            scope = scope,
        }
    end
end

--- Registers a toggle for a setting
---@param name string # the name of the toggle
---@param option string # the name of the option
---@param toggle_fn fun(enabled: boolean, buffer: integer) # the function to call when the toggle is triggered
---@param opts? { description?: string, scope?: core.settings.ToggleScope|core.settings.ToggleScope[], default?: boolean } # optional modifiers
function M.register_setting(name, option, toggle_fn, opts)
    opts = opts or {}
    opts.description = opts.description or option

    if opts.default == nil then
        opts.default = true
    end

    assert(type(opts.description) == 'string' and opts.description ~= '')

    local scopes = opts.scope and utils.to_list(opts.scope) or utils.to_list 'global'
    assert(vim.tbl_islist(scopes))

    register(name, scopes, function(buffer)
        if buffer then
            return M.get(option, { buffer = buffer, default = opts.default })
        else
            return M.get(option, { default = opts.default })
        end
    end, function(buffer)
        local enabled = M.toggle(option, { buffer = buffer, description = opts.description, default = opts.default })
        local buffers = buffer ~= nil and { buffer } or utils.get_listed_buffers()

        for _, b in ipairs(buffers) do
            toggle_fn(enabled and M.get(option, { buffer = b }), b)
        end
    end)
end

--- Shows a list of toggles
---@param buffer? integer # the buffer to show toggles for, or 0 or nil for current buffer
function M.show(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    ---@type (string|integer)[][]
    local items = {}
    local sorted = vim.tbl_deep_extend('force', {}, registry)

    table.sort(sorted, function(a, b)
        if a.name == b.name then
            return a.scope < b.scope
        else
            return a.name < b.name
        end
    end)

    for _, item in ipairs(sorted) do
        ---@type string[]
        local entry = {}

        table.insert(entry, item.name)
        table.insert(entry, item.scope)

        local value = item.value_fn(item.scope == 'buffer' and buffer or nil)
        table.insert(entry, value and 'on' or 'off')

        table.insert(items, entry)
    end

    require('ui.select').advanced(items, {
        prompt = 'Toggle option',
        separator = ' | ',
        highlighter = function(_, index, col_index)
            local item = sorted[index]
            if col_index < 3 then
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
        callback = function(_, index)
            local fn = sorted[index].toggle_fn
            if sorted[index].scope == 'buffer' then
                fn(vim.api.nvim_get_current_buf())
            else
                fn()
            end
        end,
        index_fields = { 1, 2 },
    })
end

--- Serializes the relevant settings to a JSON string
---@return string # the serialized settings
function M.serialize_to_json()
    local buf_opts = {}
    for buffer, settings in pairs(permanent_settings) do
        buf_opts[vim.api.nvim_buf_get_name(buffer)] = settings
    end

    local settings = {
        global = global_settings,
        files = buf_opts,
    }

    return vim.json.encode(settings) or '{}'
end

--- Restores settings from a serialized JSON string
---@param opts string # the serialized settings
function M.deserialize_from_json(opts)
    utils.info(vim.inspect(vim.json.decode(opts)))
end

vim.keymap.set('n', '<leader>uu', M.show, { desc = 'Toggle options' })

return M
