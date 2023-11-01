local utils = require 'utils'
local lsp = require 'utils.lsp'
local project = require 'utils.project'
local settings = require 'utils.settings'

local M = {}

local setting_name = 'auto_linting_enabled'

--- Gets the names of all active linters for a buffer
---@param buffer integer # the buffer to get the linters for
---@return string[] # the names of the active linters
local function linters(buffer)
    assert(type(buffer) == 'number' and buffer)
    if not package.loaded['lint'] then
        return {}
    end

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

--- Gets the names of all active linters for a buffer
---@param buffer integer|nil # the buffer to get the linters for or nil for current
---@return string[] # the names of the active linters
function M.active_names_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()
    return linters(buffer)
end

--- Checks whether there are any active linters for a buffer
---@param buffer integer|nil # the buffer to check the linters for or nil for current
---@return boolean # whether there are any active linters
function M.active_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    return #linters(buffer) > 0
end

--- Applies all active linters to a buffer
---@param buffer integer|nil # the buffer to apply the linters to or nil for current
---@param force boolean|nil # whether to force the linting
function M.apply(buffer, force)
    if not force and (not settings.get_global(setting_name, true) or not settings.get_permanent_for_buffer(buffer, setting_name, true)) then
        return
    end

    buffer = buffer or vim.api.nvim_get_current_buf()

    -- check if we have any linters for this fie type
    local names = linters(buffer)
    if #names == 0 then
        return
    end

    local lint = require 'lint'

    utils.debounce(100, function()
        local do_lint = function()
            lint.try_lint(names, { cwd = project.root(buffer) })
        end

        -- lint current buffer or inside another buffer
        if buffer == vim.api.nvim_get_current_buf() then
            do_lint()
        else
            vim.api.nvim_buf_call(buffer, do_lint)
        end
    end)
end

--- Toggles auto-linting for a buffer
---@param buffer integer|nil # the buffer to toggle the linters for or nil for current
function M.toggle_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local enabled = settings.get_permanent_for_buffer(buffer, setting_name, true)

    local file_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buffer), ':t')

    utils.info(string.format('Turning **%s** auto-linting for *%s*.', enabled and 'off' or 'on', file_name))
    settings.set_permanent_for_buffer(buffer, setting_name, not enabled)

    if enabled then
        -- clear diagnostics from buffer linters
        lsp.clear_diagnostics(linters(buffer), buffer)
    else
        -- re-lint
        M.apply(buffer)
    end
end

--- Toggles auto-linting globally
function M.toggle()
    local enabled = settings.get_global(setting_name, true)

    utils.info(string.format('Turning **%s** auto-linting *globally*.', enabled and 'off' or 'on'))
    settings.set_global(setting_name, not enabled)

    if enabled then
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
