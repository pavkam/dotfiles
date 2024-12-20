local events = require 'events'
local lsp = require 'lsp'
local progress = require 'progress'

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

    ---@type vim.Diagnostic[]
    local matching = vim.iter(diagnostics)
        :filter(
            ---@param d vim.Diagnostic
            function(d)
                return d.lnum <= row and d.end_lnum >= row
            end
        )
        :totable()

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
---@param severity vim.diagnostic.Severity|nil "ERROR"|"WARN"|"INFO"|"HINT"|nil # the severity
---to jump to, or nil for all
function M.jump(next_or_prev, severity)
    local go = next_or_prev and vim.diagnostic.goto_next or vim.diagnostic.goto_prev

    local sev = severity and vim.diagnostic.severity[severity] or nil
    go { severity = sev }
end

-- TODO: fix this diagnostics module:
-- https://github.com/artemave/workspace-diagnostics.nvim/blob/main/lua/workspace-diagnostics/init.lua
local indexing_in_progress = false

--- Check all files in the workspace for diagnostics
---@param client vim.lsp.Client table # the LSP client
---@param files string[] # the files to check
---@param index integer # the index of the current file
local function check_file(client, files, index)
    assert(type(client) == 'table')
    assert(vim.islist(files))

    indexing_in_progress = index <= #files
    events.trigger_status_update_event()

    if not indexing_in_progress then
        return
    end

    local path = files[index]
    progress.update('workspace', {
        ctx = string.format('Checking %d of %d files', index, #files),
    })

    local ok, buffer = pcall(vim.fn.bufadd, path)
    if ok then
        client.notify(vim.lsp.protocol.Methods.textDocument_didOpen, {
            textDocument = {
                uri = vim.uri_from_fname(path),
                version = 0,
                text = vim.fn.join(vim.fn.readfile(path), '\n'),
                languageId = ide.ft.detect(path),
            },
        })

        vim.defer_fn(function()
            client.request_sync(vim.lsp.protocol.Methods.textDocument_publishDiagnostics, {
                textDocument = {
                    uri = vim.uri_from_fname(path),
                    version = 0,
                    text = vim.fn.join(vim.fn.readfile(path), '\n'),
                    languageId = ide.ft.detect(path),
                },
            }, 1000, buffer)

            check_file(client, files, index + 1)
        end, 10)
    else
        check_file(client, files, index + 1)
    end
end

--- Forces the LSP client to check all files in the workspace for diagnostics
---@param client vim.lsp.Client table # the LSP client
---@param target vim.fn.Target # the target to check
function M.check_workspace(client, target)
    if not client.server_capabilities.textDocumentSync.openClose then
        return
    end

    local git = require 'git'
    local project = require 'project'

    git.tracked(project.root(target) or vim.fn.cwd(), function(paths)
        indexing_in_progress = true

        check_file(client, paths, 1)

        progress.update('workspace', {
            fn = function()
                return indexing_in_progress
            end,
            ctx = 'Checking workspace...',
            timeout = math.huge,
        })
    end)
end

ide.command.register('DiagnoseWorkspace', function()
    ide.tui.info 'Checking workspace diagnostics...'

    ---@type vim.lsp.Client[]
    local clients = vim.iter(vim.lsp.get_clients())
        :filter(function(client)
            return not lsp.is_special(client)
        end)
        :totable()

    for _, client in ipairs(clients) do
        M.check_workspace(client)
    end
end, { desc = 'Diagnose workspace' })

return M
