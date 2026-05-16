-- StyledText: owned replacement for nui.text.
-- A text chunk with optional highlight group.

local StyledText = Class('StyledText')

---@param content string
---@param hl_group string|nil
function StyledText:init(content, hl_group)
    self._content = content or ''
    self._hl_group = type(hl_group) == 'string' and hl_group or nil
    self._length = #content
    self._width = vim.api.nvim_strwidth(content)
end

---@return string
function StyledText:content()
    return self._content
end

---@return integer
function StyledText:length()
    return self._length
end

---@return integer
function StyledText:width()
    return self._width
end

---@param bufnr integer
---@param ns_id integer
---@param linenr integer # 1-indexed
---@param byte_start integer # 0-indexed
function StyledText:highlight(bufnr, ns_id, linenr, byte_start)
    if not self._hl_group then return end
    pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id >= 0 and ns_id or vim.api.nvim_create_namespace(''), linenr - 1, byte_start, {
        end_col = byte_start + self._length,
        hl_group = self._hl_group,
    })
end

---@return string
function StyledText:__tostring()
    return self._content
end

return StyledText
