local utils = require 'core.utils'
local settings = require 'core.settings'

---@class core.toggles
local M = {}

--- Toggles a transient option for a buffer
---@param option string # the name of the option
---@param opts? { buffer?: integer, default?: boolean, description?: string } # optional modifiers
---@return boolean # whether the option is enabled
local function toggle(option, opts)
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

    settings.set(option, not enabled, { buffer = opts.buffer })

    return not enabled
end

--- Toggles diagnostics on or off
---@param opts? { buffer?: integer } # optional modifiers
function M.toggle_diagnostics(opts)
    opts = opts or {}

    local enabled = toggle('diagnostics_enabled', { buffer = opts.buffer, description = 'diagnostics', default = true })
    if not enabled then
        vim.diagnostic.disable(opts.buffer)
    else
        vim.diagnostic.enable(opts.buffer)
    end
end

--- Toggles treesitter on or off
---@param opts? { buffer?: integer } # optional modifiers
function M.toggle_treesitter(opts)
    opts = opts or {}
    opts.buffer = opts.buffer or vim.api.nvim_get_current_buf()

    local enabled = toggle('treesitter_enabled', { buffer = opts.buffer, description = 'treesitter', default = true })

    if not enabled then
        vim.treesitter.stop(opts.buffer)
    else
        vim.treesitter.start(opts.buffer)
    end
end

--- Toggles ignoring of hidden files on or off
function M.toggle_ignore_hidden_files()
    local ignore = toggle('ignore_hidden_files', { description = 'hiding ignored files', default = true })

    -- Update Neo-Tree state
    local mgr = require 'neo-tree.sources.manager'
    mgr.get_state('filesystem').filtered_items.visible = not ignore
end

--- Toggles auto-autoformatting on or off
---@param opts? { buffer?: integer } # optional modifiers
function M.toggle_auto_formatting(opts)
    local format = require 'formatting'

    opts = opts or {}
    opts.buffer = opts.buffer == nil and nil or opts.buffer or vim.api.nvim_get_current_buf()

    local enabled = toggle('auto_formatting_enabled', { buffer = opts.buffer, description = 'auto-linting', default = true })

    local buffers = opts.buffer ~= nil and { opts.buffer } or utils.get_listed_buffers()

    if enabled then
        -- re-format
        for _, buffer in ipairs(buffers) do
            if settings.buf[buffer].auto_formatting_enabled and settings.global.auto_formatting_enabled then
                format.apply(buffer)
            end
        end
    end
end

--- Toggles auto-linting on or off
---@param opts? { buffer?: integer } # optional modifiers
function M.toggle_auto_linting(opts)
    local lint = require 'linting'
    local lsp = require 'project.lsp'

    opts = opts or {}
    if opts.buffer ~= nil then
        opts.buffer = opts.buffer or vim.api.nvim_get_current_buf()
    end

    local enabled = toggle('auto_linting_enabled', { buffer = opts.buffer, description = 'auto-linting', default = true })

    local buffers = opts.buffer ~= nil and { opts.buffer } or utils.get_listed_buffers()

    if not enabled then
        -- clear diagnostics
        for _, buffer in ipairs(buffers) do
            lsp.clear_diagnostics(lint.active_names_for_buffer(buffer), buffer)
        end
    else
        -- re-lint
        for _, buffer in ipairs(buffers) do
            if settings.buf[buffer].auto_linting_enabled and settings.global.auto_linting_enabled then
                lint.apply(buffer)
            end
        end
    end
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

--- Shows a list of toggles
---@param buffer? integer # the buffer to show toggles for, or 0 or nil for current buffer
function M.show(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    ---@type (string|integer)[][]
    local items = {}
    for _, item in ipairs(registry) do
        ---@type string[]
        local entry = {}

        table.insert(entry, item.name)
        table.insert(entry, ' ' .. item.scope .. ' ')

        local value = item.value_fn(item.scope == 'buffer' and buffer or nil)
        table.insert(entry, value and 'on' or 'off')

        table.insert(items, entry)
    end

    require('ui.select').advanced(items, {
        prompt = 'Toggle option',
        highlighter = function(_, index, col_index)
            local item = registry[index]
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
            local fn = registry[index].toggle_fn
            if registry[index].scope == 'buffer' then
                fn(vim.api.nvim_get_current_buf())
            else
                fn()
            end
        end,
        index_fields = { 1, 2 },
    })
end

local icons = require 'ui.icons'

register(icons.UI.Lint .. ' Auto-linting', function(buffer)
    if buffer then
        return settings.buf[buffer].auto_linting_enabled
    else
        return settings.global.auto_linting_enabled
    end
end, function(buffer)
    M.toggle_auto_linting { buffer = buffer }
end, { scope = { 'buffer', 'global' } })

vim.keymap.set('n', '<leader>uu', M.show, { desc = 'Toggle options' })

return M
