local utils = require 'core.utils'
local settings = require 'core.settings'

---@class core.toggles
local M = {}

--- Toggles a transient option for a buffer
---@param option string # the name of the option
---@param opts? { buffer?: integer, default?: boolean, description?: string } # optional modifiers
---@return boolean # whether the option is enabled
function M.toggle(option, opts)
    assert(type(option) == 'string' and option ~= '')

    opts = opts or {}
    opts.description = opts.description or option
    assert(type(opts.description) == 'string' and opts.description ~= '')

    local enabled = settings.get(option, { buffer = opts.buffer, default = opts.default })

    if opts.buffer ~= nil then
        local file_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(opts.buffer), ':t')
        utils.info(string.format('Turning **%s** %s for *%s*.', enabled and 'off' or 'on', opts.description, file_name))
    else
        utils.info(string.format('Turning **%s** %s *globally*.', enabled and 'off' or 'on', opts.description))
    end

    settings.set(option, not enabled, { buffer = opts.buffer, scope = 'permanent' })

    return not enabled
end

---@alias core.toggles.Scope 'buffer' | 'global'

---@class core.toggles.RegistryItem
---@field name string
---@field value_fn fun(buffer?: integer): boolean
---@field toggle_fn fun(buffer?: integer)
---@field scope core.toggles.Scope

---@type core.toggles.RegistryItem[]
local registry = {}

--- Registers a toggle
---@param name string # the name of the toggle
---@param value_fn fun(buffer?: integer): boolean # the function to call to get the current value of the toggle
---@param toggle_fn fun(buffer?: integer) # the function to call when the toggle is triggered
---@param opts? { scope: core.toggles.Scope|core.toggles.Scope[] } # optional modifiers
local function register(name, value_fn, toggle_fn, opts)
    assert(type(name) == 'string' and name ~= '')
    assert(type(toggle_fn) == 'function')
    assert(type(value_fn) == 'function')

    opts = opts or {}
    local scopes = opts.scope and utils.to_list(opts.scope) or utils.to_list 'global'

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
---@param scope core.toggles.Scope|core.toggles.Scope[] # the scope(s) of the toggle
---@param toggle_fn fun(enabled: boolean, buffer: integer) # the function to call when the toggle is triggered
function M.register_setting(name, option, scope, toggle_fn, opts)
    opts = opts or {}
    opts.description = opts.description or option
    assert(type(opts.description) == 'string' and opts.description ~= '')

    register(name, function(buffer)
        if buffer then
            return settings.buf[buffer][option]
        else
            return settings.global[option]
        end
    end, function(buffer)
        local enabled = M.toggle(option, { buffer = buffer, description = opts.description, default = opts.default })
        local buffers = buffer ~= nil and { buffer } or utils.get_listed_buffers()

        for _, b in ipairs(buffers) do
            toggle_fn(enabled and settings.buf[b][option], b)
        end
    end, { scope = scope })
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
            if registry[index].scope == 'buffer' then
                fn(vim.api.nvim_get_current_buf())
            else
                fn()
            end
        end,
        index_fields = { 1, 2 },
    })
end

--- Serializes the current toggles to a string
---@return string # the serialized options
function M.serialize()
    return vim.json.encode(settings.snapshot()) or '{}'
end

--- Restores toggles from a serialized string
---@param opts string # the serialized options
function M.deserialize(opts)
    utils.info(vim.inspect(vim.json.decode(opts)))
end

vim.keymap.set('n', '<leader>uu', M.show, { desc = 'Toggle options' })

return M
