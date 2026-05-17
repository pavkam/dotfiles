-- LSP keymaps extension: capability-gated keybindings for LSP features.
-- Uses buffer-centric API: buf:lsp() for all LSP operations.

local Extension = require 'ide.Extension'
local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'

local LspKeymaps = Class('LspKeymaps', Extension)

function LspKeymaps:init()
    Extension.init(self, 'LspKeymaps')
end

--- Rename with post-rename summary and quickfix population.
--- Intercepts the workspace edit to count changes and list affected files.
---@param buf any # Buffer instance
function LspKeymaps:_rename_with_summary(buf)
    local bufnr = buf:id()
    local word = vim.fn.expand('<cword>')

    IDE.ui:input('Rename', function(new_name)
        if not new_name or new_name == '' or new_name == word then return end

        local params = vim.lsp.util.make_position_params(0, 'utf-8')
        params.newName = new_name

        vim.lsp.buf_request(bufnr, 'textDocument/rename', params, function(err, result)
            if err then
                IDE.ui:error('Rename failed: ' .. (err.message or tostring(err)))
                return
            end
            if not result then return end

            -- Apply the workspace edit
            local enc = vim.lsp.get_clients({ bufnr = bufnr })[1]
            local offset_encoding = enc and enc.offset_encoding or 'utf-8'
            vim.lsp.util.apply_workspace_edit(result, offset_encoding)

            -- Collect changes from both response formats
            local changes = {}
            if result.documentChanges then
                for _, change in ipairs(result.documentChanges) do
                    if change.edits then
                        changes[change.textDocument.uri] = change.edits
                    end
                end
            elseif result.changes then
                changes = result.changes
            end

            -- Build notification and quickfix entries
            local file_count = vim.tbl_count(changes)
            local edit_count = 0
            local qf_items = {}
            local summary_lines = { 'Rename changes:' }

            for uri, edits in pairs(changes) do
                edit_count = edit_count + #edits
                local path = vim.uri_to_fname(uri)
                local display = IDE.fs:display_path(path)

                summary_lines[#summary_lines + 1] = string.format('  %d in %s', #edits, display)

                for _, edit in ipairs(edits) do
                    qf_items[#qf_items + 1] = {
                        filename = path,
                        lnum = (edit.range.start.line or 0) + 1,
                        col = (edit.range.start.character or 0) + 1,
                        text = 'Renamed to: ' .. new_name,
                    }
                end
            end

            -- Populate quickfix with all rename locations
            if #qf_items > 0 then
                IDE.quickfix:set(qf_items, { title = 'Rename: ' .. new_name })
            end

            -- Show summary notification
            if file_count > 0 then
                IDE.ui:info(string.format(
                    'Renamed to "%s": %d edit%s across %d file%s',
                    new_name, edit_count, edit_count == 1 and '' or 's',
                    file_count, file_count == 1 and '' or 's'
                ))
            end
        end)
    end, { default = word })
end

function LspKeymaps:_attach(ctx, client, bufnr)
    local buf = Buffer.get(bufnr)
    local Methods = vim.lsp.protocol.Methods

    local function supports(method)
        return client:supports_method(method)
    end

    local function bind(mode, lhs, rhs, cap, desc)
        if supports(cap) then
            ctx:keymap(mode, lhs, rhs, { buffer = bufnr, desc = desc })
        end
    end

    -- Navigation (finder operations go through IDE.ui.finder — it's a UI concern, not buffer)
    bind('n', 'gd', function() IDE.ui.finder:definitions({ reuse_win = true }) end, Methods.textDocument_definition, 'Goto definition')
    bind('n', 'gr', function() IDE.ui.finder:references() end, Methods.textDocument_references, 'References')
    bind('n', 'gD', function() buf:lsp():declaration() end, Methods.textDocument_declaration, 'Goto declaration')
    bind('n', 'gI', function() IDE.ui.finder:implementations() end, Methods.textDocument_implementation, 'Goto implementation')
    bind('n', 'gy', function() IDE.ui.finder:type_definitions() end, Methods.textDocument_typeDefinition, 'Goto type definition')

    -- Info
    bind('n', 'K', function() buf:lsp():hover() end, Methods.textDocument_hover, 'Hover')
    bind('n', '<C-k>', function() buf:lsp():show_diagnostic() end, Methods.textDocument_publishDiagnostics, 'Line diagnostics')
    bind('n', 'gK', function() buf:lsp():signature_help() end, Methods.textDocument_signatureHelp, 'Signature help')
    bind('n', 'gl', function() buf:lsp():run_codelens() end, Methods.textDocument_codeLens, 'Run CodeLens')

    -- Actions
    bind('n', '<M-CR>', function() buf:lsp():code_action() end, Methods.textDocument_codeAction, 'Code actions')
    bind('v', '<M-CR>', function() buf:lsp():code_action() end, Methods.textDocument_codeAction, 'Code actions')

    -- Rename: LSP rename on identifiers (with summary), text replace on other nodes
    local ext = self
    if supports(Methods.textDocument_rename) then
        ctx:keymap('n', '<C-r>', function()
            if buf:ast():node_category() == 'identifier' then
                ext:_rename_with_summary(buf)
            else
                IDE.keys:feed(IDE.text:rename_expression())
            end
        end, { buffer = bufnr, desc = 'Rename' })
    end

    -- Document highlight with * and # navigation
    if supports(Methods.textDocument_documentHighlight) then
        ctx:keymap('n', '*', function()
            if not IDE.lsp:jump_reference(1) then Window.current():exec_normal('*') end
        end, { buffer = bufnr, desc = 'Next occurrence' })
        ctx:keymap('n', '#', function()
            if not IDE.lsp:jump_reference(-1) then Window.current():exec_normal('#') end
        end, { buffer = bufnr, desc = 'Prev occurrence' })

        ctx:hook({ 'CursorHold', 'CursorHoldI' }, function()
            buf:lsp():clear_references()
            buf:lsp():highlight_references()
        end, { buffer = bufnr, desc = 'Document highlight' })

        ctx:hook({ 'CursorMoved', 'CursorMovedI', 'BufLeave' }, function()
            buf:lsp():clear_references()
        end, { buffer = bufnr, desc = 'Clear highlight refs' })
    end

    -- Per-buffer feature toggles
    if supports(Methods.textDocument_codeLens) and IDE.config:is_enabled('code_lens_enabled') then
        buf:lsp():enable_codelens(true)
    end

    if supports(Methods.textDocument_inlayHint) then
        buf:lsp():enable_inlay_hints(IDE.config:is_enabled('inlay_hint_enabled'))
    end

    if supports(Methods.textDocument_semanticTokens_full)
        or supports(Methods.textDocument_semanticTokens_full_delta)
        or supports(Methods.textDocument_semanticTokens_range) then
        if not IDE.config:is_enabled('semantic_tokens_enabled') then
            ctx:defer(100, function()
                buf:lsp():enable_semantic_tokens(false, client.id)
            end)
        end
    end
end

--- Find a visible LSP hover/signature float and scroll it by `delta` lines.
--- Uses IDE Window/Buffer abstractions for float detection and cursor control.


function LspKeymaps:on_register(ctx)
    local ext = self

    ctx:hook('LspAttach', function(evt)
        local client = IDE.lsp:client_by_id(evt.data.client_id)
        if client then
            ext:_attach(ctx, client, evt.buf)
        end
    end, { desc = 'Attach LSP keymaps' })
end

return LspKeymaps
