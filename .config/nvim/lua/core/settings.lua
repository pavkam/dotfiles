local utils = require 'core.utils'
local icons = require 'ui.icons'

---@type table<string, any>
local global_permanent_settings = {}
---@type table<integer, any>
local global_instance_settings = {}
---@type table<integer, table<string, any>>
local buffer_permanent_settings = {}
---@type table<integer, table<string, any>>
local buffer_instance_settings = {}
---@type table<integer, table<string, any>>
local buffer_transient_settings = {}

---@type table<string, table<string, any>>
local file_permanent_settings = {}

---@class core.settings
local M = {}

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
        local val = M.get(var_name, { buffer = buffer, scope = 'transient' })
        if val == nil then
            val = fn(buffer)
            M.set(var_name, val, { buffer = buffer, scope = 'transient' })
        end

        return val
    end
end

---@alias core.settings.Scope 'transient' | 'permanent' | 'instance'

--- Changes the value of an option
---@param option string # the name of the option
---@param value any|nil # the value of the option
---@param opts? { buffer?: integer, scope: core.settings.Scope } # optional options
function M.set(option, value, opts)
    assert(type(option) == 'string' and option ~= '')
    assert(type(opts) == 'table')

    assert(opts.scope == 'transient' or opts.scope == 'permanent' or opts.scope == 'instance')

    if opts.scope == 'permanent' and opts.buffer == nil then
        if global_permanent_settings[option] ~= value then
            global_permanent_settings[option] = value
        end
    elseif opts.scope == 'instance' and opts.buffer == nil then
        if global_instance_settings[option] ~= value then
            global_instance_settings[option] = value
        end
    else
        opts.buffer = opts.buffer or vim.api.nvim_get_current_buf()
        if opts.scope == 'instance' then
            if not buffer_instance_settings[opts.buffer] then
                buffer_instance_settings[opts.buffer] = {}
            end
            buffer_instance_settings[opts.buffer][option] = value
        elseif opts.scope == 'transient' then
            if not buffer_transient_settings[opts.buffer] then
                buffer_transient_settings[opts.buffer] = {}
            end
            buffer_transient_settings[opts.buffer][option] = value
        elseif opts.scope == 'permanent' then
            if not buffer_permanent_settings[opts.buffer] then
                buffer_permanent_settings[opts.buffer] = {}
            end
            buffer_permanent_settings[opts.buffer][option] = value
            file_permanent_settings[vim.api.nvim_buf_get_name(opts.buffer)] = buffer_permanent_settings[opts.buffer]
        end
    end
    --
    -- if opts.scope ~= 'transient' then
    --     utils.trigger_status_update_event()
    -- end
end

--- Gets a global option
---@param option string # the name of the option
---@param opts { buffer?: integer, default?: any, scope: core.settings.Scope } # optional options
---@return any|nil # the value of the option
function M.get(option, opts)
    assert(type(option) == 'string' and option ~= '')
    assert(type(opts) == 'table')

    assert(opts.scope == 'transient' or opts.scope == 'permanent' or opts.scope == 'instance')

    local val
    if opts.scope == 'permanent' and opts.buffer == nil then
        val = global_permanent_settings[option]
    elseif opts.scope == 'instance' and opts.buffer == nil then
        val = global_instance_settings[option]
    else
        local buffer = opts.buffer or vim.api.nvim_get_current_buf()
        if opts.scope == 'transient' then
            val = buffer_transient_settings[buffer] and buffer_transient_settings[buffer][option]
        elseif opts.scope == 'instance' then
            val = buffer_instance_settings[buffer] and buffer_instance_settings[buffer][option]
        elseif opts.scope == 'permanent' then
            val = buffer_permanent_settings[buffer] and buffer_permanent_settings[buffer][option]
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
function M.snapshot(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local settings = {
        buffer_transient = buffer_transient_settings[buffer],
        buffer_permanent = buffer_permanent_settings[buffer],
        buffer_instance = buffer_instance_settings[buffer],
        global_permanent = global_permanent_settings,
        global_instance = global_instance_settings,
    }

    return settings
end

---@alias core.settings.ToggleScope 'buffer' | 'global'

---@class core.settings.ManagedToggle
---@field name string
---@field option string
---@field value_fn fun(buffer?: integer): boolean
---@field toggle_fn fun(buffer?: integer)
---@field scope core.settings.ToggleScope

---@type core.settings.ManagedToggle[]
local managed_toggles = {}

---@class core.settings.RegisterToggleOpts # The options for registering a toggle
---@field name string|nil # the name of the option
---@field description string|nil # the description of the option
---@field scope core.settings.ToggleScope|core.settings.ToggleScope[] # the scope of the option
---@field default boolean|nil # the default value of the option

--- Registers a managed toggle setting
---@param option string # the name of the option
---@param toggle_fn fun(enabled: boolean, buffer?: integer) # the function to call when the toggle is triggered
---@param opts core.settings.RegisterToggleOpts|nil # the options for the toggle
function M.register_toggle(option, toggle_fn, opts)
    opts = opts or {}
    opts.name = opts.name or option
    opts.description = opts.description or option
    opts.scope = opts.scope or 'global'

    if opts.default == nil then
        opts.default = true
    end

    assert(type(opts.description) == 'string' and opts.description ~= '')
    assert(type(opts.name) == 'string' and opts.name ~= '')
    assert(type(toggle_fn) == 'function')

    local scopes = assert(utils.to_list(opts.scope))

    for _, scope in ipairs(scopes) do
        assert(scope == 'buffer' or scope == 'global')

        local get_value = scope == 'buffer'
                and function(buffer)
                    return M.get(option, { buffer = buffer, default = opts.default, scope = 'permanent' })
                end
            or function()
                return M.get(option, { default = opts.default, scope = 'permanent' })
            end

        local toggle_value = function(buffer)
            local enabled = get_value(buffer)

            if buffer ~= nil then
                local file_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buffer), ':t')
                utils.hint(
                    string.format(
                        icons.UI.Toggle .. '  Turning `%s` `%s` for `%s`.',
                        enabled and 'off' or 'on',
                        opts.description,
                        file_name
                    )
                )
            else
                utils.hint(
                    string.format(
                        icons.UI.Toggle .. '  Turning `%s` `%s` globally.',
                        enabled and 'off' or 'on',
                        opts.description
                    )
                )
            end

            enabled = not enabled
            M.set(option, enabled, { buffer = buffer, scope = 'permanent' })

            if scope == 'global' then
                toggle_fn(enabled, nil)

                if vim.tbl_contains(scopes, 'buffer') then
                    local buffers = utils.get_listed_buffers()
                    for _, b in ipairs(buffers) do
                        toggle_fn(
                            enabled and M.get(option, { buffer = b, default = opts.default, scope = 'permanent' }),
                            b
                        )
                    end
                end
            elseif scope == 'buffer' then
                toggle_fn(
                    enabled and M.get(option, { buffer = buffer, default = opts.default, scope = 'permanent' }),
                    buffer
                )
            else
                error 'invalid scope'
            end
        end

        table.insert(managed_toggles, {
            name = opts.name,
            option = option,
            toggle_fn = toggle_value,
            value_fn = get_value,
            scope = scope,
        })
    end
end

--- Gets a managed toggle
---@param option string # the name of the option
---@param scope core.settings.ToggleScope # the scope of the option
---@return core.settings.ManagedToggle|nil # the toggle
local function find_toggle(option, scope)
    return vim.iter(managed_toggles)
        :filter(function(toggle)
            return toggle.option == option and toggle.scope == scope
        end)
        :next()
end

--- Gets the value of a managed toggle
---@param option string # the name of the option
---@param buffer integer|nil # the buffer to get the option for combined with the global (if available)
---@return boolean # the value of the option
function M.get_toggle(option, buffer)
    assert(type(option) == 'string' and option ~= '')
    if buffer == 0 then
        buffer = vim.api.nvim_get_current_buf()
    end

    local global_toggle = find_toggle(option, 'global')
    local buffer_toggle = find_toggle(option, 'buffer')

    if global_toggle and buffer_toggle then
        return global_toggle.value_fn() and buffer_toggle.value_fn(buffer)
    elseif global_toggle then
        return global_toggle.value_fn()
    elseif buffer_toggle then
        return buffer_toggle.value_fn(buffer)
    else
        return false
    end
end

--- Toggles a managed option
---@param option string # the name of the option
---@param buffer integer| nil # the buffer to toggle the option for. If nil, toggle globally
---@param value boolean|nil # if nil, it will toggle the current value, otherwise it will set the value
function M.set_toggle(option, buffer, value)
    assert(type(option) == 'string' and option ~= '')
    if buffer == 0 then
        buffer = vim.api.nvim_get_current_buf()
    end

    local toggle = assert(find_toggle(option, buffer and 'buffer' or 'global'))

    if value == nil or toggle.value_fn(buffer) ~= value then
        toggle.toggle_fn(buffer)
    end
end

--- Shows the list of managed toggles
---@param buffer integer|nil # the buffer to show toggles for, or 0 or nil for current buffer
function M.show_settings_ui(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    ---@type (string|integer)[][]
    local items = {}
    local sorted = vim.tbl_deep_extend('force', {}, managed_toggles)

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

---@class core.settings.Exported
---@field global table<string, any>
---@field files table<string, table<string, any>>

--- Exports the settings to a table
--- @return core.settings.Exported
function M.export()
    return {
        global = global_permanent_settings,
        files = file_permanent_settings,
    }
end

--- Restores settings from an exported table
---@param settings core.settings.Exported # the exported settings
function M.import(settings)
    assert(type(settings) == 'table' and settings.global and settings.files)

    -- restore global toggles
    for option, value in pairs(settings.global) do
        local toggle = find_toggle(option, 'global')

        if toggle and type(value) == 'boolean' then
            -- restore the toggle
            M.set_toggle(toggle.option, nil, value)
        else
            -- save the value for later
            M.set(option, value, { scope = 'permanent' })
        end
    end

    -- restore file toggles
    for file_name, file_settings in pairs(settings.files) do
        local buffer = vim.fn.bufnr(file_name --[[@as integer]])

        if buffer == -1 or vim.fn.bufloaded(buffer) == 0 then
            -- save the settings for later
            file_permanent_settings[file_name] = file_settings
        else
            for option, value in pairs(file_settings) do
                local toggle = find_toggle(option, 'buffer')
                if toggle and type(value) == 'boolean' then
                    -- restore the toggle
                    M.set_toggle(toggle.option, buffer, value)
                else
                    -- save the value for later
                    M.set(option, value, { buffer = buffer, scope = 'permanent' })
                end
            end
        end
    end
end

-- Clear the options for a buffer
utils.on_event({ 'LspDetach', 'LspAttach', 'BufWritePost', 'BufEnter', 'VimResized' }, function()
    vim.schedule(utils.trigger_status_update_event)
end)

utils.on_event('BufReadPost', function(evt)
    -- copy the settings from the file to the buffer
    local settings = file_permanent_settings[vim.api.nvim_buf_get_name(evt.buf)]

    -- reset buffer's settings on re-read
    buffer_permanent_settings[evt.buf] = nil

    -- restore file toggles
    if settings then
        for option, value in pairs(settings) do
            local toggle = find_toggle(option, 'buffer')
            if toggle and type(value) == 'boolean' then
                -- restore the toggle
                M.set_toggle(toggle.option, evt.buf, value)
            end
        end
    end
end)

utils.on_event('BufDelete', function(evt)
    -- clear the settings for the buffer
    buffer_transient_settings[evt.buf] = nil
    buffer_instance_settings[evt.buf] = nil
    buffer_permanent_settings[evt.buf] = nil
end)

utils.on_status_update_event(function(evt)
    buffer_transient_settings[evt.buf] = nil

    -- refresh the status showing components
    if package.loaded['lualine'] then
        local refresh = require('lualine').refresh

        ---@diagnostic disable-next-line: param-type-mismatch
        pcall(refresh)
    end
end)

vim.keymap.set('n', '<leader>u', M.show_settings_ui, { desc = icons.UI.UI .. ' Show options' })

return M
