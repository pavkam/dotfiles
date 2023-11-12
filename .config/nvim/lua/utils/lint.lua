local utils = require 'utils'
local lsp = require 'utils.lsp'
local project = require 'utils.project'
local settings = require 'utils.settings'

---@class utils.lint
local M = {}

local setting_name = 'auto_linting_enabled'

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

--- Monitors the status of a linter and updates the progress
---@param buffer integer|nil # the buffer to monitor the linter for or 0 or nil for current buffer
---@param linter string # the name of the linter to monitor
local function poll_linting_status(buffer, linter)
    assert(type(linter) == 'string' and linter ~= '')

    local lint = require 'lint'

    buffer = buffer or vim.api.nvim_get_current_buf()

    utils.poll(buffer, function(actual_buffer)
        ---@type table<integer, table<string, lint.LintProc>>
        local tbl = utils.get_up_value(lint.try_lint, 'running_procs_by_buf')
        local handle = tbl and tbl[actual_buffer] ~= nil and tbl[actual_buffer][linter] ~= nil and tbl[actual_buffer][linter].handle
        ---@diagnostic disable-next-line: undefined-field
        local running = handle and not handle:is_closing()

        print(vim.inspect(tbl))

        local key = string.format('linter_%s_progress', linter)
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

--- Gets the progress of a linter for a buffer
---@param buffer integer|nil # the buffer to get the linter progress for or 0 or nil for current
---@param linter string # the name of the linter to get the progress for
---@return integer|nil # the progress of the linter or nil if not running
function M.get_linting_progress(buffer, linter)
    assert(type(linter) == 'string' and linter ~= '')

    local key = string.format('linter_%s_progress', linter)
    return settings.get_permanent_for_buffer(buffer, key, nil)
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

--- Checks whether auto-linting is enabled for a buffer
---@param buffer integer|nil # the buffer to check the linting for or 0 or nil for current
---@return boolean # whether auto-linting is enabled
function M.enabled_for_buffer(buffer)
    return settings.get_toggle_for_buffer(buffer, setting_name)
end

--- Applies all active linters to a buffer
---@param buffer integer|nil # the buffer to apply the linters to or 0 or nil for current
---@param force boolean|nil # whether to force the linting
function M.apply(buffer, force)
    if not force and not M.enabled_for_buffer(buffer) then
        return
    end

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
            for _, name in ipairs(names) do
                poll_linting_status(buffer, name)
            end
        end

        vim.api.nvim_buf_call(buffer, do_lint)
    end, 100)
end

--- Toggles auto-linting for a buffer
---@param buffer integer|nil # the buffer to toggle the linters for or nil for current
function M.toggle_for_buffer(buffer)
    local enabled = settings.toggle_for_buffer(buffer, setting_name, 'auto-linting')

    if not enabled then
        -- clear diagnostics from buffer linters
        lsp.clear_diagnostics(linters(buffer), buffer)
    else
        -- re-lint
        M.apply(buffer)
    end
end

--- Toggles auto-linting globally
function M.toggle()
    local enabled = settings.toggle_global(setting_name, 'auto-linting')

    if not enabled then
        -- clear diagnostics from all buffers
        for _, buffer in ipairs(utils.get_listed_buffers()) do
            lsp.clear_diagnostics(linters(buffer), buffer)
        end
    else
        -- re-lint
        for _, buffer in ipairs(utils.get_listed_buffers()) do
            M.apply(buffer)
        end
    end
end

return M
