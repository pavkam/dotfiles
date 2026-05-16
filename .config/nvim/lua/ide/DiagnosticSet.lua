-- DiagnosticSet: buffer-scoped diagnostic abstraction.
-- Wraps vim.diagnostic.* into a clean API with severity filtering.

local DiagnosticSet = Class('DiagnosticSet')

DiagnosticSet.ERROR = vim.diagnostic.severity.ERROR
DiagnosticSet.WARN = vim.diagnostic.severity.WARN
DiagnosticSet.HINT = vim.diagnostic.severity.HINT
DiagnosticSet.INFO = vim.diagnostic.severity.INFO

---@param bufnr integer
function DiagnosticSet:init(bufnr)
    self._bufnr = bufnr
end

--- Get all diagnostics.
---@param severity integer|nil # vim.diagnostic.severity value
---@return vim.Diagnostic[]
function DiagnosticSet:list(severity)
    return vim.diagnostic.get(self._bufnr, severity and { severity = severity } or nil)
end

--- Count diagnostics.
---@param severity integer|nil
---@return integer
function DiagnosticSet:count(severity)
    return #self:list(severity)
end

function DiagnosticSet:errors() return self:count(vim.diagnostic.severity.ERROR) end
function DiagnosticSet:warnings() return self:count(vim.diagnostic.severity.WARN) end
function DiagnosticSet:hints() return self:count(vim.diagnostic.severity.HINT) end
function DiagnosticSet:infos() return self:count(vim.diagnostic.severity.INFO) end

---@return boolean
function DiagnosticSet:has_errors() return self:errors() > 0 end

---@return boolean
function DiagnosticSet:has_warnings() return self:warnings() > 0 end

---@return boolean
function DiagnosticSet:is_clean() return self:count() == 0 end

--- Jump to next diagnostic.
---@param severity integer|nil
function DiagnosticSet:next(severity)
    vim.diagnostic.jump { count = 1, severity = severity }
end

--- Jump to previous diagnostic.
---@param severity integer|nil
function DiagnosticSet:prev(severity)
    vim.diagnostic.jump { count = -1, severity = severity }
end

--- Clear all diagnostics.
---@param namespace integer|nil
function DiagnosticSet:clear(namespace)
    vim.diagnostic.reset(namespace, self._bufnr)
end

--- Show diagnostics in a float.
function DiagnosticSet:show_float()
    vim.diagnostic.open_float()
end

--- Send diagnostics to the quickfix list.
function DiagnosticSet:to_quickfix()
    vim.diagnostic.setqflist()
end

--- Get a summary string.
---@return string
function DiagnosticSet:summary()
    local e, w, h, i = self:errors(), self:warnings(), self:hints(), self:infos()
    local parts = {}
    if e > 0 then parts[#parts + 1] = e .. 'E' end
    if w > 0 then parts[#parts + 1] = w .. 'W' end
    if i > 0 then parts[#parts + 1] = i .. 'I' end
    if h > 0 then parts[#parts + 1] = h .. 'H' end
    return #parts > 0 and table.concat(parts, ' ') or 'clean'
end

---@return string
function DiagnosticSet:__tostring()
    return string.format('DiagnosticSet(buf=%d, %s)', self._bufnr, self:summary())
end

return DiagnosticSet
