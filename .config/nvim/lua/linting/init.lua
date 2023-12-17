local utils = require 'core.utils'
local project = require 'project'
local progress = require 'ui.progress'

---@class linting
local M = {}

-- TODO: linting times out for Go files

local progress_class = 'linting'

--- Gets the names of all active linters for a buffer
---@param buffer integer|nil # the buffer to get the linters for or 0 or nil for current
---@return string[] # the names of the active linters
local function linters(buffer)
    if not package.loaded['lint'] then
        return {}
    end

    buffer = buffer or vim.api.nvim_get_current_buf()

    local lint = require 'lint'
    local clients = vim.api.nvim_buf_is_valid(buffer) and lint.linters_by_ft[vim.bo[buffer].filetype] or {}

    local file_name = vim.api.nvim_buf_get_name(buffer)
    local ctx = {
        filename = file_name,
        dirname = vim.fn.fnamemodify(file_name, ':h'),
        buf = buffer,
    }

    return vim.tbl_filter(function(name)
        local linter = lint.linters[name]
        ---@diagnostic disable-next-line: undefined-field
        return linter and not (type(linter) == 'table' and linter.condition and not linter.condition(ctx))
    end, clients)
end

--- Checks the status of linting for a buffer
---@param buffer integer # the buffer to monitor the linting for
---@return boolean # whether linting is running
local function linting_status(buffer)
    assert(type(buffer) == 'number')

    local lint = require 'lint'

    ---@type table<integer, table<string, lint.LintProc>>
    local tbl = utils.get_up_value(lint.try_lint, 'running_procs_by_buf')
    local running_linters = tbl and tbl[buffer] or {}

    for _, linter in pairs(running_linters) do
        ---@diagnostic disable-next-line: undefined-field
        local running = linter.handle and not linter.handle:is_closing()

        if running then
            return true
        end
    end

    return false
end

--- Gets the progress of linting for a buffer
---@param buffer integer|nil # the buffer to get the linter progress for or 0 or nil for current
---@return string|nil,string[]|nil # the progress of the linter or nil if not running
function M.progress(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    return progress.status_for_buffer(buffer, progress_class)
end

--- Gets the names of all active linters for a buffer
---@param buffer integer|nil # the buffer to get the linters for or 0 or nil for current
---@return string[] # the names of the active linters
function M.active_names_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()
    return linters(buffer)
end

--- Checks whether there are any active linters for a buffer
---@param buffer integer|nil # the buffer to check the linters for or 0 or nil for current
---@return boolean # whether there are any active linters
function M.active_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    return #linters(buffer) > 0
end

--- Applies all active linters to a buffer
---@param buffer integer|nil # the buffer to apply the linters to or 0 or nil for current
function M.apply(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    -- check if we have any linters for this fie type
    local names = linters(buffer)
    if #names == 0 then
        return
    end

    local lint = require 'lint'

    utils.defer_unique(buffer, function()
        local do_lint = function()
            lint.try_lint(names, { cwd = project.root(buffer) })
            progress.register_task_for_buffer(buffer, progress_class, { prv = true, fn = linting_status, ctx = names })
        end

        if vim.api.nvim_buf_is_valid(buffer) then
            vim.api.nvim_buf_call(buffer, do_lint)
        end
    end, 100)
end

return M
