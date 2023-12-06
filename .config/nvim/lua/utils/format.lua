local utils = require 'utils'
local progress = require 'utils.progress'

---@class utils.format
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

    local conform = require 'conform'
    local ok, clients = pcall(conform.list_formatters, buffer)

    if not ok then
        return {}
    end

    return vim.tbl_map(function(v)
        return v.name
    end, clients)
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
    buffer = buffer or vim.api.nvim_get_current_buf()

    return progress.status_for_buffer(buffer, progress_class)
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

    if not vim.api.nvim_buf_is_valid(buffer) then
        return
    end

    local additional = injected and { formatters = { 'injected' } } or {}

    conform.format(utils.tbl_merge({ bufnr = buffer }, additional))

    local names = formatters(buffer)
    if #names > 0 then
        progress.register_task_for_buffer(buffer, progress_class, { prv = true, fn = formatting_status, ctx = names })
    end
end

return M
