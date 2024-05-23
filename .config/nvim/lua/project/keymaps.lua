local utils = require 'core.utils'
local syntax = require 'editor.syntax'
local lsp = require 'project.lsp'
local icons = require 'ui.icons'

---@class languages.keymaps
local M = {}
local keymaps = {
    {
        'gd',
        function()
            if lsp.is_active_for_buffer(nil, 'omnisharp') then
                require('omnisharp_extended').telescope_lsp_definitions()
            else
                require('telescope.builtin').lsp_definitions { reuse_win = true }
            end
        end,
        desc = 'Goto definition',
        capability = vim.lsp.protocol.Methods.textDocument_definition,
    },
    { 'gr', '<cmd>Telescope lsp_references<cr>', desc = 'Show references', capability = vim.lsp.protocol.Methods.textDocument_references },
    { 'gD', vim.lsp.buf.declaration, desc = 'Goto declaration', capability = vim.lsp.protocol.Methods.textDocument_declaration },
    {
        'gI',
        function()
            require('telescope.builtin').lsp_implementations { reuse_win = true }
        end,
        desc = 'Goto Implementation',
        capability = vim.lsp.protocol.Methods.textDocument_implementation,
    },
    {
        'gy',
        function()
            require('telescope.builtin').lsp_type_definitions { reuse_win = true }
        end,
        desc = 'Goto Type Definition',
        capability = vim.lsp.protocol.Methods.textDocument_typeDefinition,
    },
    { '<C-k>', vim.lsp.buf.hover, desc = 'Inspect symbol', capability = vim.lsp.protocol.Methods.textDocument_hover },
    { 'gK', vim.lsp.buf.signature_help, desc = 'Signature help', capability = vim.lsp.protocol.Methods.textDocument_signatureHelp },
    {
        'gl',
        vim.lsp.codelens.run,
        desc = 'Run CodeLens',
        capability = vim.lsp.protocol.Methods.textDocument_codeLens,
    },
    {
        '<M-CR>',
        vim.lsp.buf.code_action,
        desc = icons.UI.Action .. ' Code actions',
        mode = { 'n', 'v' },
        capability = vim.lsp.protocol.Methods.textDocument_codeAction,
    },
    {
        '<C-r>',
        function()
            local is_identifier =
                vim.tbl_contains({ 'identifier', 'property_identifier', 'type_identifier' }, require('editor.syntax').node_type_under_cursor())

            if is_identifier then
                vim.lsp.buf.rename()
                return ':<nop><cr>'
            else
                utils.feed_keys(syntax.create_rename_expression())
            end
        end,
        desc = 'Rename',
        capability = vim.lsp.protocol.Methods.textDocument_rename,
    },
}

--- Attaches keymaps to a client
---@param client vim.lsp.Client # the client to attach the keymaps to
---@param buffer integer # the buffer to attach the keymaps to
local function attach_keymaps(client, buffer)
    assert(type(client) == 'table' and client)
    assert(type(buffer) == 'number' and buffer)

    local Keys = require 'lazy.core.handler.keys'
    local resolved_keymaps = {}

    for _, keymap in ipairs(keymaps) do
        local parsed = Keys.parse(keymap)
        resolved_keymaps[parsed.id] = parsed
    end

    for _, mapping in pairs(resolved_keymaps) do
        if not mapping.capability or client.supports_method(mapping.capability) then
            vim.keymap.set(mapping.mode or 'n', mapping.lhs, mapping.rhs, {
                desc = mapping.desc,
                buffer = buffer,
                silent = mapping.silent,
                remap = mapping.remap,
                expr = mapping.expr,
            })
        end
    end

    -- special keymaps
    if not lsp.is_special(client) then
        vim.keymap.set('n', '<leader>!', function()
            vim.cmd.write()

            lsp.clear_diagnostics(nil)
            lsp.restart_all_for_buffer()

            vim.treesitter.stop()
            vim.cmd.edit()
            vim.treesitter.start()
        end, { buffer = buffer, desc = icons.UI.Nuke .. ' Nuke buffer state' })
    end
end

--- Attaches keymaps to a client
---@param client vim.lsp.Client # the client to attach the keymaps to
---@param buffer integer|nil # the buffer to attach the keymaps to or nil for current
function M.attach(client, buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    attach_keymaps(client, buffer)

    lsp.on_capability_event({ 'InsertLeave', 'BufEnter' }, vim.lsp.protocol.Methods.textDocument_codeLens, buffer, function()
        vim.lsp.codelens.refresh { bufnr = buffer }
    end, true)

    lsp.on_capability_event({ 'CursorHold', 'CursorHoldI' }, vim.lsp.protocol.Methods.textDocument_documentHighlight, buffer, function()
        vim.lsp.buf.document_highlight()
    end)

    lsp.on_capability_event({ 'CursorMoved', 'CursorMovedI', 'BufLeave' }, vim.lsp.protocol.Methods.textDocument_documentHighlight, buffer, function()
        vim.lsp.buf.clear_references()
    end)

    lsp.on_capability_event({ 'BufRead', 'BufNew' }, vim.lsp.protocol.Methods.textDocument_inlayHint, buffer, function()
        vim.lsp.inlay_hint.enable(true, { bufnr = buffer })
    end, true)
end

return M
