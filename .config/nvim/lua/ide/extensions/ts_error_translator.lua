-- TypeScript error translator extension.
-- Replaces dmmulroy/ts-error-translator.nvim.
-- Intercepts TypeScript LSP diagnostics and translates cryptic TS error codes
-- into human-readable messages using a static database.

local Extension = require 'ide.Extension'
local TsErrorTranslator = Class('TsErrorTranslator', Extension)

function TsErrorTranslator:init()
    Extension.init(self, 'TsErrorTranslator')
    self._db = nil
    self._servers = { 'vtsls', 'ts_ls', 'tsserver', 'typescript-tools' }
end

--- Lazy-load the error database.
---@return table<number, { pattern: string, improved_message?: string }>
function TsErrorTranslator:_get_db()
    if not self._db then
        self._db = require 'ide.extensions.ts_error_db'
    end
    return self._db
end

--- Translate a TS diagnostic message.
---@param message string
---@param code number|string|nil
---@return string
function TsErrorTranslator:translate(message, code)
    if not code then return message end

    local num_code = tonumber(tostring(code))
    if not num_code then return message end

    local db = self:_get_db()
    local entry = db[num_code]
    if not entry or not entry.improved_message then return message end

    return entry.improved_message .. '\n\n(TS' .. num_code .. ': ' .. message .. ')'
end

function TsErrorTranslator:on_register(ctx)
    local ext = self

    local original_handler = vim.lsp.handlers['textDocument/publishDiagnostics']

    vim.lsp.handlers['textDocument/publishDiagnostics'] = function(err, result, lsp_ctx, config)
        if result and result.diagnostics then
            local client = vim.lsp.get_client_by_id(lsp_ctx.client_id)
            local client_name = client and client.name or ''

            if vim.tbl_contains(ext._servers, client_name) then
                for _, diag in ipairs(result.diagnostics) do
                    if diag.message and diag.code then
                        diag.message = ext:translate(diag.message, diag.code)
                    end
                end
            end
        end

        return original_handler(err, result, lsp_ctx, config)
    end

    ctx:notify('TypeScript error translator active')
end

return TsErrorTranslator
