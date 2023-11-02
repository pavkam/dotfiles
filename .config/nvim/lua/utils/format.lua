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
---@param force boolean|nil # whether to force the formatting
---@param injected boolean|nil # whether to format injected code
function M.apply(buffer, force, injected)
    local conform = require 'conform'

    settings.get_permanent_for_buffer(buffer, 'auto_format_enabled', true)
    if not force and (not settings.get_global(setting_name, true) or not settings.get_permanent_for_buffer(buffer, 'auto_format_enabled', true)) then
        return
    end

    buffer = buffer or vim.api.nvim_get_current_buf()

    if not vim.api.nvim_buf_is_valid(buffer) then
        return
    end

    local additional = injected and { formatters = { 'injected' } } or {}

    conform.format(utils.tbl_merge({ bufnr = buffer }, additional))
end

--- Toggles auto-formatting for a buffer
---@param buffer integer|nil # the buffer to toggle the formatting for or 0 or nil for current
function M.toggle_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local enabled = settings.get_permanent_for_buffer(buffer, setting_name, true)

    local file_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buffer), ':t')
    utils.info(string.format('Turning **%s** auto-formatting for *%s*.', enabled and 'off' or 'on', file_name))
    settings.set_permanent_for_buffer(buffer, setting_name, not enabled)

    if not enabled then
        -- re-format
        M.apply(buffer)
    end
end

--- Toggles auto-formatting globally
function M.toggle()
    local enabled = settings.get_global(setting_name, true)

    utils.info(string.format('Turning **%s** auto-formatting *globally*.', enabled and 'off' or 'on'))
    settings.set_global(setting_name, not enabled)

    if not enabled then
        -- re-format
        for _, buffer in ipairs(utils.get_listed_buffers()) do
            M.apply(buffer)
        end
    end
end

return M
