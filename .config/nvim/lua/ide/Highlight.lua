-- Highlight: fluent builder for highlight groups.

local Highlight = Class('Highlight')

---@param name string
function Highlight:init(name)
    self._name = name
    self._opts = {}
end

function Highlight:name() return self._name end

function Highlight:fg(color)
    if color:sub(1, 1) == '#' then
        self._opts.fg = color
    else
        local hl = vim.api.nvim_get_hl(0, { name = color, link = false })
        self._opts.fg = hl.fg and string.format('#%06x', hl.fg) or nil
    end
    return self
end

function Highlight:bg(color)
    if color:sub(1, 1) == '#' then
        self._opts.bg = color
    else
        local hl = vim.api.nvim_get_hl(0, { name = color, link = false })
        self._opts.bg = hl.bg and string.format('#%06x', hl.bg) or nil
    end
    return self
end

function Highlight:bold() self._opts.bold = true; return self end
function Highlight:italic() self._opts.italic = true; return self end
function Highlight:underline() self._opts.underline = true; return self end
function Highlight:nocombine() self._opts.nocombine = true; return self end
function Highlight:as_default() self._opts.default = true; return self end
function Highlight:link(target) self._opts = { link = target }; return self end

function Highlight:define(ns)
    vim.api.nvim_set_hl(ns or 0, self._name, self._opts)
    return self
end

function Highlight:fg_hex()
    local hl = vim.api.nvim_get_hl(0, { name = self._name, link = false })
    return hl.fg and string.format('#%06x', hl.fg) or nil
end

function Highlight:bg_hex()
    local hl = vim.api.nvim_get_hl(0, { name = self._name, link = false })
    return hl.bg and string.format('#%06x', hl.bg) or nil
end

function Highlight:__tostring() return string.format('Highlight(%s)', self._name) end

function Highlight.get(name) return Highlight(name) end

return Highlight
