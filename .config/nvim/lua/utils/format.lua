local utils = require 'utils'
local settings = require 'utils.settings'

---@class utils.format
local M = {}

local setting_name = 'format_enabled'

--- Gets the names of all active formatters for a buffer
---@param buffer integer # the buffer to get the formatters for
---@return string[] # the names of the active formatters
local function formatters(buffer)
    assert(type(buffer) == 'number' and buffer)

    local conform = require 'conform'
    local ok, clients = pcall(conform.list_formatters, buffer)

    if not ok then
        return {}
    end

    return vim.tbl_map(function(v)
        return v.name
    end, clients)
end

--- Monitors the status of a formatter and updates the progress
---@param buffer integer # the buffer to monitor the linter for
local function poll_formatting_status(buffer)
    utils.poll(buffer, function(actual_buffer)
        local jid = vim.b[actual_buffer].conform_jid
        local running = not jid or vim.fn.jobwait({ jid }, 0)[0] == -1

        local key = 'formatting_progress'
        local progress = settings.get_permanent_for_buffer(actual_buffer, key, 0)

        if running then
            settings.set_permanent_for_buffer(actual_buffer, key, progress + 1)
        else
            settings.set_permanent_for_buffer(actual_buffer, key, nil)
        end

        utils.trigger_status_update_event()

        return not running
    end, 200)
end

--- Gets the progress of a formatter for a buffer
---@param buffer integer|nil # the buffer to get the linter progress for or 0 or nil for current
---@return integer|nil # the progress of the formatter or nil if not running
function M.progress(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()
    return settings.get_permanent_for_buffer(buffer, 'formatting_progress', nil)
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

--- Checks whether auto-formatting is enabled for a buffer
---@param buffer integer|nil # the buffer to check the formatting for or 0 or nil for current
---@return boolean # whether auto-formatting is enabled
function M.enabled_for_buffer(buffer)
    return settings.get_toggle_for_buffer(buffer, setting_name)
end

--- Applies all active formatters to a buffer
---@param buffer integer|nil # the buffer to apply the formatters to or 0 or nil for current
---@param force boolean|nil # whether to force the formatting
---@param injected boolean|nil # whether to format injected code
function M.apply(buffer, force, injected)
    local conform = require 'conform'

    if not force and not M.enabled_for_buffer(buffer) then
        return
    end

    buffer = buffer or vim.api.nvim_get_current_buf()

    if not vim.api.nvim_buf_is_valid(buffer) then
        return
    end

    local additional = injected and { formatters = { 'injected' } } or {}

    conform.format(utils.tbl_merge({ bufnr = buffer }, additional))
    poll_formatting_status(buffer)
end

--- Toggles auto-formatting for a buffer
---@param buffer integer|nil # the buffer to toggle the formatting for or 0 or nil for current
function M.toggle_for_buffer(buffer)
    local enabled = settings.toggle_for_buffer(buffer, setting_name, 'auto-formatting')
    if enabled then
        -- re-format
        M.apply(buffer)
    end
end

--- Toggles auto-formatting globally
function M.toggle()
    local enabled = settings.toggle_global(setting_name, 'auto-formatting')
    if enabled then
        -- re-format
        for _, buffer in ipairs(utils.get_listed_buffers()) do
            M.apply(buffer)
        end
    end
end

return M
