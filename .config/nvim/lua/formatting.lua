local events = require 'events'
local keys = require 'keys'
local settings = require 'settings'
local icons = require 'icons'
-- TODO: can we preload eslind and prettier? or make sure the async works?

---@class formatting
local M = {}

--- Gets the names of all active formatters for a buffer
---@param buffer integer # the buffer to get the formatters for
---@return string[] # the names of the active formatters
local function formatters(buffer)
    assert(type(buffer) == 'number' and buffer)

    if not ide.plugins.has 'conform.nvim' then
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

--- Gets the names of all active formatters for a buffer.
---@param buffer integer|nil # the buffer to get the formatters for or nil for current.
---@return string[] # the names of the active formatters.
function M.active(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()
    return formatters(buffer)
end

--- Applies all active formatters to a buffer.
---@param buffer integer|nil # the buffer to apply the formatters to or 0 or nil for current.
function M.apply(buffer)
    local conform = require 'conform'

    buffer = buffer or vim.api.nvim_get_current_buf()
    if not vim.buf.is_regular(buffer) then
        return
    end

    local names = formatters(buffer)
    if #names > 0 then
        local tracked_task = ide.async
            .track_task('formatting', {
                buffer = ide.buf[buffer],
            })
            .update(function(running)
                return table.merge(table.list_to_set(running or {}), table.list_to_set(names))
            end)

        conform.format({
            bufnr = buffer,
            formatters = names,
            quiet = false,
            lsp_format = 'fallback',
            timeout_ms = 5000,
        }, function()
            tracked_task.update(function(running)
                running = table.without_keys(running or {}, names)
                return next(running) and running or nil
            end)
        end)
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
    if enabled then
        M.apply(buffer)
    end
end, { icon = icons.UI.Format, name = 'Auto-formatting', scope = { 'buffer', 'global' } })

if ide.plugins.has 'conform.nvim' then
    keys.map({ 'n', 'x' }, '=', function()
        M.apply()
    end, { desc = 'Format buffer/selection' })

    events.on_event('BufWritePre', function(evt)
        if M.enabled(evt.buf) then
            M.apply(evt.buf)
        end
    end, '*')
end

return table.freeze(M)
