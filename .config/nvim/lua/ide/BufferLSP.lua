-- BufferLSP: per-buffer LSP client facade.
-- Accessed via buf:lsp(). Wraps all LSP operations scoped to a specific buffer.
-- The buffer owns its LSP relationship — no singleton needed for buffer-scoped ops.

local BufferLSP = Class('BufferLSP')

---@param bufnr integer
function BufferLSP:init(bufnr)
    self._bufnr = bufnr
end

--- Get all LSP clients attached to this buffer.
---@return vim.lsp.Client[]
function BufferLSP:clients()
    return vim.lsp.get_clients({ bufnr = self._bufnr })
end

--- Check if any LSP client is attached.
---@return boolean
function BufferLSP:is_attached()
    return #self:clients() > 0
end

--- Check if a specific capability is available.
---@param method string # LSP method name
---@return boolean
function BufferLSP:has_capability(method)
    return #vim.lsp.get_clients({ bufnr = self._bufnr, method = method }) > 0
end

--- Check if a specific server is attached.
---@param name string
---@return boolean
function BufferLSP:has_server(name)
    return #vim.lsp.get_clients({ name = name, bufnr = self._bufnr }) > 0
end

--- Get client names.
---@return string[]
function BufferLSP:client_names()
    local names = {}
    for _, c in ipairs(self:clients()) do
        names[#names + 1] = c.name
    end
    return names
end

-- Actions (all scoped to this buffer via nvim_buf_call)

local function _in_buf(bufnr, fn)
    vim.api.nvim_buf_call(bufnr, fn)
end

function BufferLSP:hover()
    _in_buf(self._bufnr, vim.lsp.buf.hover)
end

function BufferLSP:definition()
    _in_buf(self._bufnr, vim.lsp.buf.definition)
end

function BufferLSP:declaration()
    _in_buf(self._bufnr, vim.lsp.buf.declaration)
end

function BufferLSP:references()
    _in_buf(self._bufnr, vim.lsp.buf.references)
end

function BufferLSP:implementation()
    _in_buf(self._bufnr, vim.lsp.buf.implementation)
end

function BufferLSP:type_definition()
    _in_buf(self._bufnr, vim.lsp.buf.type_definition)
end

function BufferLSP:rename()
    _in_buf(self._bufnr, vim.lsp.buf.rename)
end

function BufferLSP:code_action()
    _in_buf(self._bufnr, vim.lsp.buf.code_action)
end

function BufferLSP:signature_help()
    _in_buf(self._bufnr, vim.lsp.buf.signature_help)
end

function BufferLSP:format(opts)
    opts = opts or {}
    vim.lsp.buf.format({ bufnr = self._bufnr, timeout_ms = opts.timeout_ms or 5000 })
end

-- Document highlights

function BufferLSP:highlight_references()
    _in_buf(self._bufnr, vim.lsp.buf.document_highlight)
end

function BufferLSP:clear_references()
    _in_buf(self._bufnr, vim.lsp.buf.clear_references)
end

-- Feature toggles (per-buffer)

function BufferLSP:enable_inlay_hints(enabled)
    vim.lsp.inlay_hint.enable(enabled, { bufnr = self._bufnr })
end

function BufferLSP:enable_codelens(enabled)
    vim.lsp.codelens.enable(enabled, { bufnr = self._bufnr })
end

function BufferLSP:enable_semantic_tokens(enabled, client_id)
    vim.lsp.semantic_tokens.enable(enabled, { bufnr = self._bufnr, client_id = client_id })
end

function BufferLSP:run_codelens()
    vim.lsp.codelens.run()
end

--- Enable native LSP completion for this buffer.
---@param client_id integer
---@param opts? { autotrigger?: boolean }
function BufferLSP:enable_completion(client_id, opts)
    opts = opts or {}
    vim.lsp.completion.enable(true, client_id, self._bufnr, {
        autotrigger = opts.autotrigger ~= false,
    })
end

--- Trigger the completion popup.
function BufferLSP:trigger_completion()
    vim.lsp.completion.trigger()
end

--- Show diagnostic float for this buffer.
function BufferLSP:show_diagnostic()
    vim.diagnostic.open_float({ bufnr = self._bufnr })
end

---@return string
function BufferLSP:__tostring()
    return string.format('BufferLSP(buf=%d, %d clients)', self._bufnr, #self:clients())
end

return BufferLSP
