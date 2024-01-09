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
        capability = 'definition',
    },
    { 'gr', '<cmd>Telescope lsp_references<cr>', desc = 'Show references', capability = 'references' },
    { 'gD', vim.lsp.buf.declaration, desc = 'Goto declaration', capability = 'declaration' },
    {
        'gI',
        function()
            require('telescope.builtin').lsp_implementations { reuse_win = true }
        end,
        desc = 'Goto Implementation',
        capability = 'implementation',
    },
    {
        'gy',
        function()
            require('telescope.builtin').lsp_type_definitions { reuse_win = true }
        end,
        desc = 'Goto Type Definition',
        capability = 'typeDefinition',
    },
    { 'gK', vim.lsp.buf.signature_help, desc = 'Signature help', capability = 'signatureHelp' },
    {
        'gl',
        vim.lsp.codelens.run,
        desc = 'Run CodeLens',
        capability = 'codeLens',
    },
    { '<leader><cr>', vim.lsp.buf.code_action, desc = icons.UI.Action .. ' Code actions', mode = { 'n', 'v' }, capability = 'codeAction' },
    {
        '<C-r>',
        function()
            local is_identifier = vim.tbl_contains({ 'identifier', 'property_identifier' }, require('editor.syntax').node_type_under_cursor())
            if is_identifier then
                vim.lsp.buf.rename()
                return ':<nop><cr>'
            else
                local command = [[:%s/\<<C-r><C-w>\>//gI<Left><Left><Left><C-r><C-w>]]
                vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(command, true, false, true), 'n', false)
            end
        end,
        desc = 'Rename',
        capability = 'rename',
    },
}

--- Attaches keymaps to a client
---@param client LspClient # the client to attach the keymaps to
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
---@param client LspClient # the client to attach the keymaps to
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
            inlay_hint.enable(buffer, true)
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
