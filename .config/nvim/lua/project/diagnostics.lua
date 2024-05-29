local utils = require 'core.utils'
local lsp = require 'project.lsp'
local progress = require 'ui.progress'

---@class project.diagnostics
local M = {}

--- Checks if there is a diagnostic at the current position
---@param row integer # the row to check
---@param buffer integer|nil # the buffer to check, or 0 or nil for the current buffer
---@return vim.Diagnostic[] # whether there is a diagnostic at the current position
function M.for_position(buffer, row)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local diagnostics = vim.diagnostic.get(buffer)
    if #diagnostics == 0 then
        return {}
    end

    local matching = vim.tbl_filter(function(d)
        --[[@cast d vim.Diagnostic]]
        return d.lnum <= row and d.end_lnum >= row
    end, diagnostics)

    ---@cast matching vim.Diagnostic[]
    return matching
end

--- Checks if there is a diagnostic at the current position
---@param window integer|nil # the window to check, or 0 or nil for the current window
---@return vim.Diagnostic[] # whether there is a diagnostic at the current position
function M.for_current_position(window)
    window = window or vim.api.nvim_get_current_win()
    local buffer = vim.api.nvim_win_get_buf(window)

    local row = vim.api.nvim_win_get_cursor(window)[1]

    return M.for_position(buffer, row - 1)
end

--- Jump to the next or previous diagnostic
---@param next_or_prev boolean # whether to jump to the next or previous diagnostic
---@param severity vim.diagnostic.Severity|nil "ERROR"|"WARN"|"INFO"|"HINT"|nil # the severity to jump to, or nil for all
function M.jump(next_or_prev, severity)
    local go = next_or_prev and vim.diagnostic.goto_next or vim.diagnostic.goto_prev

    local sev = severity and vim.diagnostic.severity[severity] or nil
    go { severity = sev }
end

---@type table<string, integer>
local checked_files = {}
local indexing_in_progress = false

--- Check all files in the workspace for diagnostics
---@param client vim.lsp.Client table # the LSP client
---@param files string[] # the files to check
---@param index integer # the index of the current file
local function check_file(client, files, index)
    if index > #files then
        indexing_in_progress = false
        return
    end

    vim.schedule(function()
        local path = files[index]
        if path ~= vim.api.nvim_buf_get_name(0) or checked_files[path] ~= vim.fn.getftime(path) then
            progress.register_task('workspace', {
                ctx = string.format('Checking %d of %d files', index, #files),
            })

            local ok = pcall(vim.fn.bufadd, path)
            if ok then
                client.notify('textDocument/didOpen', {
                    textDocument = {
                        uri = vim.uri_from_fname(path),
                        version = 0,
                        text = vim.fn.join(vim.fn.readfile(path), '\n'),
                        languageId = utils.file_type(path),
                    },
                })
            end

            --- store the last modified time of the file
            checked_files[path] = vim.fn.getftime(path)
            utils.trigger_status_update_event()
        end

        check_file(client, files, index + 1)
    end)
end

--- Forces the LSP client to check all files in the workspace for diagnostics
---@param client vim.lsp.Client table # the LSP client
---@param target string|integer|nil # the target to get the root for
function M.check_workspace(client, target)
    if not client.server_capabilities.textDocumentSync.openClose then
        return
    end

    local git = require 'git'
    local project = require 'project'

    git.tracked(project.root(target) or vim.fn.cwd(), function(paths)
        indexing_in_progress = true

        check_file(client, paths, 1)

        progress.register_task('workspace', {
            fn = function()
                return indexing_in_progress
            end,
            ctx = 'Checking workspace...',
            timeout = 60 * 1000,
        })
    end)
end

utils.register_function('Check', 'Check all files', {
    ['do'] = function()
        local clients = vim.tbl_filter(function(client)
            return not lsp.is_special(client)
        end, vim.lsp.get_clients())

        for _, client in ipairs(clients) do
            M.check_workspace(client)
        end
    end,
})

return M
