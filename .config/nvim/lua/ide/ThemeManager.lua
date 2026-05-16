-- ThemeManager: colorscheme and highlight group management.

local EventEmitter = require 'ide.EventEmitter'

local ThemeManager = Class('ThemeManager')
Class.include(ThemeManager, EventEmitter)

function ThemeManager:init()
    self._groups = {} ---@type table<string, table>
end

--- Set the colorscheme.
---@param name string
function ThemeManager:set_colorscheme(name)
    local ok, err = pcall(vim.cmd.colorscheme, name)
    if not ok then
        vim.notify(string.format('Failed to set colorscheme %q: %s', name, err), vim.log.levels.ERROR)
        return
    end
    self:emit('colorscheme', name)
end

--- Get the current colorscheme name.
---@return string
function ThemeManager:colorscheme()
    return vim.api.nvim_exec2('colorscheme', { output = true }).output
end

--- Define a highlight group.
---@param name string
---@param opts table # { fg, bg, bold, italic, link, ... }
---@param ns integer|nil # namespace (0 = global)
function ThemeManager:define(name, opts, ns)
    vim.api.nvim_set_hl(ns or 0, name, opts)
    self._groups[name] = opts
end

--- Define a highlight group that links to another.
---@param name string
---@param target string
function ThemeManager:link(name, target)
    self:define(name, { link = target })
end

--- Register multiple highlight groups at once.
---@param groups table<string, string|table> # name → link target or opts
function ThemeManager:define_groups(groups)
    for name, spec in pairs(groups) do
        if type(spec) == 'string' then
            self:link(name, spec)
        else
            self:define(name, spec)
        end
    end
end

--- Get the fg color of a highlight group as hex.
---@param name string
---@return string|nil
function ThemeManager:fg(name)
    local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
    return hl.fg and string.format('#%06x', hl.fg) or nil
end

--- Get the bg color of a highlight group as hex.
---@param name string
---@return string|nil
function ThemeManager:bg(name)
    local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
    return hl.bg and string.format('#%06x', hl.bg) or nil
end

--- Auto-redefine groups when colorscheme changes.
function ThemeManager:_wire_events()
    vim.api.nvim_create_autocmd('ColorScheme', {
        callback = function()
            self:emit('colorscheme', self:colorscheme())
        end,
    })
end

---@return string
function ThemeManager:__tostring()
    return string.format('ThemeManager(%s, %d groups)', self:colorscheme(), vim.tbl_count(self._groups))
end

return ThemeManager
