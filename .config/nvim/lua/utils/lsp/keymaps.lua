local lsp = require 'utils.lsp'

local M = {}

local keymaps = {
    { 'M', vim.diagnostic.open_float, desc = 'Line diagnostics' },
    { '<leader>sm', 'M', remap = true, desc = 'Line diagnostics (M)' },
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
        capability = 'definition',
    },
    { '<leader>sd', 'gd', desc = 'Goto definition (gd)', remap = true, capability = 'definition' },

    { 'gr', '<cmd>Telescope lsp_references<cr>', desc = 'Show references', capability = 'references' },
    { '<leader>sr', '<cmd>Telescope lsp_references<cr>', remap = true, desc = 'References (gr)', capability = 'references' },

    { 'gD', vim.lsp.buf.declaration, desc = 'Goto declaration', capability = 'declaration' },
    { '<leader>sD', 'gD', desc = 'Goto declaration (gD)', remap = true, capability = 'declaration' },

    {
        'gI',
        function()
            require('telescope.builtin').lsp_implementations { reuse_win = true }
        end,
        desc = 'Goto Implementation',
        capability = 'implementation',
    },
    { '<leader>si', 'gI', desc = 'Goto implementation (gI)', remap = true, capability = 'implementation' },

    {
        'gy',
        function()
            require('telescope.builtin').lsp_type_definitions { reuse_win = true }
        end,
        desc = 'Goto Type Definition',
        capability = 'typeDefinition',
    },
    { '<leader>st', 'gy', desc = 'Goto type definition (gy)', remap = true, capability = 'typeDefinition' },

    { 'K', vim.lsp.buf.hover, desc = 'Hover', capability = 'hover' },
    { '<leader>sk', 'K', desc = 'Hover (K)', remap = true, capability = 'hover' },

    { 'gK', vim.lsp.buf.signature_help, desc = 'Signature Help', capability = 'signatureHelp' },
    { '<leader>sh', 'gK', desc = 'Signature Help (gK)', remap = true, capability = 'signatureHelp' },

    {
        '<leader>sL',
        function()
            vim.lsp.codelens.refresh()
        end,
        desc = 'Refresh CodeLens',
        capability = 'codeLens',
    },
    {
        '<leader>sl',
        function()
            vim.lsp.codelens.run()
        end,
        desc = 'Run CodeLens',
        capability = 'codeLens',
    },

    { '<leader>ss', vim.lsp.buf.code_action, desc = 'Code Actions', mode = { 'n', 'v' }, capability = 'codeAction' },
    {
        '<leader>sS',
        function()
            vim.lsp.buf.code_action {
                context = {
                    only = {
                        'source',
                    },
                    diagnostics = {},
                },
            }
        end,
        desc = 'Source Action',
        capability = 'codeAction',
    },
    {
        '<leader>sR',
        function()
            vim.lsp.buf.rename()
        end,
        desc = 'Rename',
        capability = 'rename',
    },
}

--- Attaches keymaps to a client
---@param client table # the client to attach the keymaps to
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
        if not mapping.capability or lsp.client_has_capability(client, mapping.capability) then
            vim.keymap.set(mapping.mode or 'n', mapping.lhs, mapping.rhs, {
                desc = mapping.desc,
                buffer = buffer,
                silent = mapping.silent,
                remap = mapping.remap,
                expr = mapping.expr,
            })
        end
    end
end

--- Attaches keymaps to a client
---@param client table # the client to attach the keymaps to
---@param buffer integer|nil # the buffer to attach the keymaps to or nil for current
function M.attach(client, buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    attach_keymaps(client, buffer)

    if lsp.client_has_capability(client, 'codeLens') then
        vim.lsp.codelens.refresh()
    end

    lsp.on_capability_event({ 'InsertLeave', 'BufEnter' }, 'codeLens', buffer, function()
        vim.lsp.codelens.refresh()
    end)

    lsp.on_capability_event({ 'CursorHold', 'CursorHoldI' }, 'documentHighlight', buffer, function()
        vim.lsp.buf.document_highlight()
    end)

    lsp.on_capability_event({ 'CursorMoved', 'CursorMovedI', 'BufLeave' }, 'documentHighlight', buffer, function()
        vim.lsp.buf.clear_references()
    end)

    if lsp.client_has_capability(client, 'inlayHint') then
        local inlay_hint = vim.lsp.buf.inlay_hint or vim.lsp.inlay_hint
        if inlay_hint then
            inlay_hint(buffer, true)
        else
            local file_type = vim.api.nvim_buf_get_option(buffer, 'filetype')

            -- go has support for inlay hints through `ray-x/go.nvim` plugin
            if file_type ~= 'go' then
                require('lsp-inlayhints').on_attach(client, buffer)
            end
        end
    end
end

return M
