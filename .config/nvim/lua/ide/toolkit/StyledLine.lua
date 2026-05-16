-- StyledLine: owned replacement for nui.line.
-- A line composed of StyledText chunks with highlights.

local StyledText = require 'ide.toolkit.StyledText'

local StyledLine = Class('StyledLine')

function StyledLine:init()
    self._texts = {}
end

---@param content string|StyledText
---@param hl_group string|nil
---@return StyledText
function StyledLine:append(content, hl_group)
    local chunk
    if type(content) == 'string' then
        chunk = StyledText(content, hl_group)
    else
        chunk = content
    end
    self._texts[#self._texts + 1] = chunk
    return chunk
end

---@return string
function StyledLine:content()
    local parts = {}
    for _, t in ipairs(self._texts) do
        parts[#parts + 1] = t:content()
    end
    return table.concat(parts)
end

---@return integer
function StyledLine:width()
    local w = 0
    for _, t in ipairs(self._texts) do
        w = w + t:width()
    end
    return w
end

---@param bufnr integer
---@param ns_id integer
---@param linenr integer # 1-indexed
function StyledLine:highlight(bufnr, ns_id, linenr)
    local byte_start = 0
    for _, text in ipairs(self._texts) do
        text:highlight(bufnr, ns_id, linenr, byte_start)
        byte_start = byte_start + text:length()
    end
end

---@param bufnr integer
---@param ns_id integer
---@param linenr integer # 1-indexed
function StyledLine:render(bufnr, ns_id, linenr)
    local content = self:content()
    vim.api.nvim_buf_set_lines(bufnr, linenr - 1, linenr, false, { content })
    self:highlight(bufnr, ns_id, linenr)
end

---@return string
function StyledLine:__tostring()
    return self:content()
end

return StyledLine
