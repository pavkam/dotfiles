local keys = require 'keys'
local syntax = require 'syntax'
local lsp = require 'lsp'
local icons = require 'icons'
local settings = require 'settings'
local highlight_nav = require 'highlight-nav'

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
    {
        'gr',
        '<cmd>Telescope lsp_references<cr>',
        desc = 'Show references',
        capability = vim.lsp.protocol.Methods.textDocument_references,
    },
    {
        'gD',
        vim.lsp.buf.declaration,
        desc = 'Goto declaration',
        capability = vim.lsp.protocol.Methods.textDocument_declaration,
    },
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
    {
        'gK',
        vim.lsp.buf.signature_help,
        desc = 'Signature help',
        capability = vim.lsp.protocol.Methods.textDocument_signatureHelp,
    },
    {
        'gl',
        vim.lsp.codelens.run,
        desc = 'Run CodeLens',
        capability = vim.lsp.protocol.Methods.textDocument_codeLens,
    },
    {
        '<M-CR>',
        vim.lsp.buf.code_action,
        icon = icons.UI.Action,
        desc = 'Code actions',
        mode = { 'n', 'v' },
        capability = vim.lsp.protocol.Methods.textDocument_codeAction,
    },
    {
        '<C-r>',
        function()
            local is_identifier = require('syntax').node_category() == 'identifier'

            if is_identifier then
                vim.lsp.buf.rename()
                return ':<nop><cr>'
            else
                keys.feed(syntax.create_rename_expression())
            end
        end,
        desc = 'Rename',
        capability = vim.lsp.protocol.Methods.textDocument_rename,
    },
    {
        '*',
        function()
            if not highlight_nav.next() then
                vim.cmd 'normal! *'
            end
        end,
        desc = 'Jump to the Next Occurrence',
        capability = vim.lsp.protocol.Methods.textDocument_documentHighlight,
    },
    {
        '#',
        function()
            if not highlight_nav.prev() then
                vim.cmd 'normal! #'
            end
        end,
        desc = 'Jump to the Previous Occurrence',
        capability = vim.lsp.protocol.Methods.textDocument_documentHighlight,
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
            keys.map(mapping.mode or 'n', mapping.lhs, mapping.rhs, {
                desc = mapping.desc,
                buffer = buffer,
                silent = mapping.silent,
                remap = mapping.remap,
                expr = mapping.expr,
                icon = mapping.icon,
            })
        end
    end
end

--- Attaches keymaps to a client
---@param client vim.lsp.Client # the client to attach the keymaps to
---@param buffer integer|nil # the buffer to attach the keymaps to or nil for current
function M.attach(client, buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    attach_keymaps(client, buffer)

    ---@type integer|nil
    local buffer_changed_tick = -1

    lsp.on_capability_event(
        { 'BufEnter', 'CursorHold' },
        vim.lsp.protocol.Methods.textDocument_codeLens,
        buffer,
        function()
            if settings.get_toggle('code_lens_enabled', buffer) then
                if buffer_changed_tick < 0 then
                    buffer_changed_tick = buffer_changed_tick + 1
                    return
                end

                local current_tick = vim.api.nvim_buf_get_changedtick(buffer)

                if buffer_changed_tick ~= current_tick then
                    vim.lsp.codelens.refresh { bufnr = buffer }
                    buffer_changed_tick = current_tick
                end
            end
        end,
        true
    )

    lsp.on_capability_event(
        { 'CursorHold', 'CursorHoldI' },
        vim.lsp.protocol.Methods.textDocument_documentHighlight,
        buffer,
        function()
            -- TODO: probably need to remove references here as well
            vim.lsp.buf.document_highlight()
        end
    )

    lsp.on_capability_event(
        { 'CursorMoved', 'CursorMovedI', 'BufLeave' },
        vim.lsp.protocol.Methods.textDocument_documentHighlight,
        buffer,
        function()
            vim.lsp.buf.clear_references()
        end
    )

    if client.supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
        vim.lsp.inlay_hint.enable(settings.get_toggle('inlay_hint_enabled', buffer), { bufnr = buffer })
    end

    if
        client.supports_method(vim.lsp.protocol.Methods.textDocument_semanticTokens_full)
        or client.supports_method(vim.lsp.protocol.Methods.textDocument_semanticTokens_full_delta)
        or client.supports_method(vim.lsp.protocol.Methods.textDocument_semanticTokens_range)
    then
        if not settings.get_toggle('semantic_tokens_enabled', buffer) then
            vim.defer_fn(function()
                vim.lsp.semantic_tokens.stop(buffer, client.id)
            end, 100)
        end
    end
end

return M
