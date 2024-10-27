local events = require 'core.events'
local keys = require 'core.keys'
local progress = require 'ui.progress'
local settings = require 'core.settings'
local icons = require 'ui.icons'
-- TODO: can we preload eslind and prettier? or make sure the async works?

---@class formatting
local M = {}

local progress_class = 'formatting'

---@type table<integer, integer>
local running_jobs = {}

--- Gets the names of all active formatters for a buffer
---@param buffer integer # the buffer to get the formatters for
---@return string[] # the names of the active formatters
local function formatters(buffer)
    assert(type(buffer) == 'number' and buffer)

    if not vim.has_plugin 'conform.nvim' then
        return {}
    end

    if not vim.buf.is_regular(buffer) then
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

--- Gets the progress of a formatter for a buffer
---@param buffer integer|nil # the buffer to get the linter progress for or 0 or nil for current
---@return string|nil,string[]|nil # the progress spinner of the formatter or nil if not running
function M.progress(buffer)
    return progress.status(progress_class, { buffer = buffer })
end

--- Gets the names of all active formatters for a buffer
---@param buffer integer|nil # the buffer to get the formatters for or nil for current
---@return string[] # the names of the active formatters
function M.active(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()
    return formatters(buffer)
end

--- Applies all active formatters to a buffer
---@param buffer integer|nil # the buffer to apply the formatters to or 0 or nil for current
function M.apply(buffer)
    if not package.loaded['conform'] then
        vim.warn 'Conform plugin is not installed!'
        return
    end

    local conform = require 'conform'

    buffer = buffer or vim.api.nvim_get_current_buf()
    if not vim.buf.is_regular(buffer) then
        return
    end

    local names = formatters(buffer)
    if #names > 0 then
        running_jobs[buffer] = (running_jobs[buffer] or 0) + 1
        conform.format({
            bufnr = buffer,
            formatters = names,
            quiet = false,
            lsp_format = 'fallback',
            timeout_ms = 5000,
        }, function()
            running_jobs[buffer] = (running_jobs[buffer] or 0) - 1
        end)

        progress.update(progress_class, {
            buffer = buffer,
            prv = true,
            fn = function(b)
                return b and running_jobs[b] and running_jobs[b] > 0 or false
            end,
            ctx = names,
        })
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
end, { icon = icons.UI.Format, name = 'Auto-formatting', scope = { 'buffer', 'global' } })

if vim.has_plugin 'conform.nvim' then
    keys.map({ 'n', 'x' }, '=', function()
        require('formatting').apply()
    end, { desc = 'Format buffer/selection' })

    events.on_event('BufWritePre', function(evt)
        if M.enabled(evt.buf) then
            require('formatting').apply(evt.buf)
        end
    end, '*')
end

return M
