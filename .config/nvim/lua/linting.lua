local events = require 'events'
local project = require 'project'
local progress = require 'progress'
local settings = require 'settings'
local icons = require 'icons'

---@class linting
local M = {}

local progress_class = 'linting'

--- Gets the names of all active linters for a buffer
---@param buffer integer|nil # the buffer to get the linters for or 0 or nil for current
---@return string[] # the names of the active linters
local function linters(buffer)

    buffer = buffer or vim.api.nvim_get_current_buf()
    if not vim.buf.is_regular(buffer) then
        return {}
    end

    local file_type = vim.api.nvim_get_option_value('filetype', { buf = buffer })


    local lint = require 'lint'
    local clients = lint.linters_by_ft[file_type] or {}

    local file_name = vim.api.nvim_buf_get_name(buffer)
    local ctx = {
        filename = file_name,
        dirname = vim.fn.fnamemodify(file_name, ':h'),
        buf = buffer,
    }

    return dbg(vim.iter(clients)
        :filter(function(name)
            local linter = lint.linters[name]
            dbg(linter)
            ---@diagnostic disable-next-line: undefined-field
            return linter and not (type(linter) == 'table' and linter.condition and not linter.condition(ctx))
        end)
        :totable())
end

--- Checks the status of linting for a buffer
---@param buffer integer # the buffer to monitor the linting for
---@return boolean # whether linting is running
local function linting_status(buffer)
    assert(type(buffer) == 'number')

    local lint = require 'lint'

    ---@type table<integer, table<string, lint.LintProc>>
    local tbl = get_up_value(lint.try_lint, 'running_procs_by_buf')
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
    return progress.status(progress_class, { buffer = buffer })
end

--- Gets the names of all active linters for a buffer
---@param buffer integer|nil # the buffer to get the linters for or 0 or nil for current
---@return string[] # the names of the active linters
function M.active(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()
    return linters(buffer)
end

local debounced_lint = vim.debounce_fn(
    ---@param buffer integer
    ---@param names string[]
    function(buffer, names)
        require('lint').try_lint(names, { cwd = project.root(buffer) })
        progress.update(progress_class, { buffer = buffer, prv = true, fn = linting_status, ctx = names })
    end,
    100
)

--- Applies all active linters to a buffer
---@param buffer integer|nil # the buffer to apply the linters to or 0 or nil for current
function M.apply(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()
    if not vim.buf.is_regular(buffer) then
        return
    end

    -- check if we have any linters for this fie type
    local names = linters(buffer)
    if #names == 0 then
        return
    end

    debounced_lint(buffer, names)
end

local setting_name = 'auto_linting_enabled'

--- Checks whether auto-linting is enabled for a buffer
---@param buffer integer|nil # the buffer to check the auto-linting for or 0 or nil for current
---@return boolean # whether auto-linting is enabled
function M.enabled(buffer)
    return settings.get_toggle(setting_name, buffer or vim.api.nvim_get_current_buf())
end

settings.register_toggle(setting_name, function(enabled, buffer)
    if not enabled then
        M.apply(buffer)
    else
        require('project.lsp').clear_diagnostics(M.active(buffer), buffer)
    end
end, {
    icon = icons.UI.Lint,
    name = 'Auto-linting',
    default = true,
    scope = { 'buffer', 'global' },
})

if vim.has_plugin 'nvim-lint' then
    -- setup auto-commands
    events.on_event({ 'BufWritePost', 'BufReadPost', 'InsertLeave' }, function(evt)
        if M.enabled(evt.buf) then
            require('linting').apply(evt.buf)
        end
    end, '*')
end

return M
