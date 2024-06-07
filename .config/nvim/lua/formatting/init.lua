local utils = require 'core.utils'
local progress = require 'ui.progress'
local settings = require 'core.settings'
local icons = require 'ui.icons'

---@class formatting
local M = {}

local progress_class = 'formatting'

--- Gets the names of all active formatters for a buffer
---@param buffer integer # the buffer to get the formatters for
---@return string[] # the names of the active formatters
local function formatters(buffer)
    assert(type(buffer) == 'number' and buffer)

    if not utils.has_plugin 'conform.nvim' then
        return {}
    end

    if not utils.is_regular_buffer(buffer) then
        return {}
    end

    local conform = require 'conform'
    local ok, clients = pcall(conform.list_formatters, buffer)

    if not ok then
        return {}
    end

    return vim.iter(clients)
        :map(function(v)
            return v.name
        end)
        :totable()
end

--- Checks the status of the formatting operation for the buffer
---@param buffer integer # the buffer to monitor the formatter for
---@return boolean # whether formatting is running
local function formatting_status(buffer)
    assert(type(buffer) == 'number')

    local jid = vim.b[buffer].conform_jid
    local running = not jid or vim.fn.jobwait({ jid }, 0)[0] == -1

    return running
end

--- Gets the progress of a formatter for a buffer
---@param buffer integer|nil # the buffer to get the linter progress for or 0 or nil for current
---@return string|nil,string[]|nil # the progress spinner of the formatter or nil if not running
function M.progress(buffer)
    return progress.status(progress_class, { buffer = buffer })
end

--- Gets the names of all active formatters for a buffer
---@param buffer integer|nil # the buffer to get the formatters for or nil for current
---@return string[] # the names of the active formatters
function M.active_names_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()
    return formatters(buffer)
end

--- Checks whether there are any active formatters for a buffer
---@param buffer integer|nil # the buffer to check the formatters for or nil for current
---@return boolean # whether there are any active formatters
function M.active_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()
    return #formatters(buffer) > 0
end

--- Applies all active formatters to a buffer
---@param buffer integer|nil # the buffer to apply the formatters to or 0 or nil for current
---@param injected boolean|nil # whether to format injected code
function M.apply(buffer, injected)
    if not package.loaded['conform'] then
        utils.warn 'Conform plugin is not installed!'
        return
    end

    local conform = require 'conform'

    buffer = buffer or vim.api.nvim_get_current_buf()
    if not utils.is_regular_buffer(buffer) then
        return
    end

    local additional = injected and { formatters = { 'injected' } } or {}

    conform.format(utils.tbl_merge({ bufnr = buffer }, additional))

    local names = formatters(buffer)
    if #names > 0 then
        progress.update(progress_class, { buffer = buffer, prv = true, fn = formatting_status, ctx = names })
    end
end

local setting_name = 'auto_formatting_enabled'

--- Checks whether formatting is enabled for a buffer
---@param buffer integer|nil # the buffer to check the formatting for or 0 or nil for current
---@return boolean # whether formatting is enabled
function M.enabled(buffer)
    return settings.get_toggle(setting_name, buffer or vim.api.nvim_get_current_buf())
end

settings.register_toggle(setting_name, function(enabled, buffer)
    local format = require 'formatting'

    if enabled then
        format.apply(buffer)
    end
end, { name = icons.UI.Format .. ' Auto-formatting', description = 'auto-formatting', scope = { 'buffer', 'global' } })

if utils.has_plugin 'conform.nvim' then
    vim.keymap.set({ 'n', 'x' }, 'g=', function()
        require('formatting').apply(nil, true)
    end, { desc = 'Format buffer/selection (injected)' })

    vim.keymap.set({ 'n', 'x' }, '=', function()
        require('formatting').apply()
    end, { desc = 'Format buffer/selection' })

    utils.on_event('BufWritePre', function(evt)
        if M.enabled(evt.buf) then
            require('formatting').apply(evt.buf)
        end
    end, '*')
end

return M
