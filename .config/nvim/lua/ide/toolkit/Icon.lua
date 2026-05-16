-- Icon: a file/filetype icon with highlight and measurement.
-- Core toolkit primitive — wraps an icon character with its display properties.
-- Similar to Position/StyledText — a value object used across the IDE.

local Icon = Class('Icon')

---@param char string
---@param hl_group string|nil
---@param name string|nil
function Icon:init(char, hl_group, name)
    self._char = char or ''
    self._hl = hl_group
    self._name = name
end

---@return string
function Icon:char()
    return self._char
end

---@return string|nil
function Icon:hl()
    return self._hl
end

---@return string|nil
function Icon:name()
    return self._name
end

---@return integer
function Icon:width()
    return vim.api.nvim_strwidth(self._char)
end

--- Pad the icon to a fixed display width.
---@param width integer
---@return string
function Icon:fit(width)
    local w = self:width()
    if w >= width then return self._char end
    return self._char .. string.rep(' ', width - w)
end

--- Return the icon formatted for statusline (%#HL#icon%*).
---@return string
function Icon:statusline()
    if self._hl then
        return string.format('%%#%s#%s%%*', self._hl, self._char)
    end
    return self._char
end

--- Return the icon formatted for statusline with padding.
---@param width integer
---@return string
function Icon:statusline_fit(width)
    if self._hl then
        return string.format('%%#%s#%s%%*', self._hl, self:fit(width))
    end
    return self:fit(width)
end

---@return string
function Icon:__tostring()
    return self._char
end

--- Default file icon.
---@return Icon
function Icon.default()
    return Icon(vim.fn.nr2char(0xf15b), 'DevIconDefault', 'Default')
end

return Icon
