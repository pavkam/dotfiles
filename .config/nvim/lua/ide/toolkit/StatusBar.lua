-- StatusBar: bottom status bar abstraction.
-- Defines sections independently of the rendering backend (lualine).
-- Each section is a provider function that returns text + highlight.
--
-- Usage:
--   local bar = StatusBar()
--   bar:left('mode', function() return vim.fn.mode(), 'ModeHL' end)
--   bar:right('position', function() return '42:10', 'Normal' end)
--   bar:apply()

local EventEmitter = require 'ide.EventEmitter'

local StatusBar = Class('StatusBar')
Class.include(StatusBar, EventEmitter)

---@class BarSection
---@field name string
---@field provider fun(): string, string|nil # returns text, highlight_group
---@field cond fun(): boolean|nil # optional condition
---@field priority integer
---@field separator string|nil
---@field on_click fun()|nil # optional click handler

function StatusBar:init()
    self._left = {}   ---@type BarSection[]
    self._center = {} ---@type BarSection[]
    self._right = {}  ---@type BarSection[]
end

---@param name string
---@param provider fun(): string, string|nil
---@param opts { cond?: fun(): boolean, priority?: integer, separator?: string, on_click?: fun() }|nil
---@return StatusBar
function StatusBar:left(name, provider, opts)
    opts = opts or {}
    self._left[#self._left + 1] = {
        name = name,
        provider = provider,
        cond = opts.cond,
        priority = opts.priority or 0,
        separator = opts.separator,
        on_click = opts.on_click,
    }
    return self
end

---@param name string
---@param provider fun(): string, string|nil
---@param opts { cond?: fun(): boolean, priority?: integer, separator?: string }|nil
---@return StatusBar
function StatusBar:center(name, provider, opts)
    opts = opts or {}
    self._center[#self._center + 1] = {
        name = name,
        provider = provider,
        cond = opts.cond,
        priority = opts.priority or 0,
        separator = opts.separator,
    }
    return self
end

---@param name string
---@param provider fun(): string, string|nil
---@param opts { cond?: fun(): boolean, priority?: integer, separator?: string, on_click?: fun() }|nil
---@return StatusBar
function StatusBar:right(name, provider, opts)
    opts = opts or {}
    self._right[#self._right + 1] = {
        name = name,
        provider = provider,
        cond = opts.cond,
        priority = opts.priority or 0,
        separator = opts.separator,
        on_click = opts.on_click,
    }
    return self
end

--- Click handler storage (delegates to Dispatch, kept as module-local for cached bytecode compat).
local _click_handlers = setmetatable({}, {
    __newindex = function(_, k, v)
        local ok, D = pcall(require, 'ide.Dispatch')
        if ok then D.click(k, v) end
    end,
})

--- Register a click handler and return a statusline click wrapper.
---@param id string
---@param fn function
---@param content string
---@return string
function StatusBar.click(id, fn, content)
    local Dispatch = require 'ide.Dispatch'
    Dispatch.click(id, fn)
    return string.format('%%@IDE_click_dispatch@%s%%X', content)
end

--- Render sections to a statusline string (native vim format).
---@param sections BarSection[]
---@return string
local function render_sections(sections)
    local parts = {}
    for _, s in ipairs(sections) do
        if not s.cond or s.cond() then
            local text, hl = s.provider()
            if text and text ~= '' then
                local rendered
                if hl then
                    rendered = string.format('%%#%s#%s%%*', hl, text)
                else
                    rendered = text
                end
                if s.on_click then
                    _click_handlers[s.name] = s.on_click
                    rendered = string.format('%%@IDE_click_dispatch@%s%%X', rendered)
                end
                parts[#parts + 1] = rendered
            end
        end
    end
    return table.concat(parts, ' ')
end

--- Build the native vim statusline string.
---@return string
function StatusBar:render()
    local left = render_sections(self._left)
    local center = render_sections(self._center)
    local right = render_sections(self._right)

    if center ~= '' then
        return left .. '%=' .. center .. '%=' .. right
    else
        return left .. '%=' .. right
    end
end

--- Apply this statusbar as the global statusline (native, no plugins).
function StatusBar:apply_native()
    local Dispatch = require 'ide.Dispatch'
    Dispatch.renderer('statusbar', function() return self:render() end)
    vim.o.statusline = '%!v:lua.IDE_render_statusbar()'
end

--- Convert sections to lualine format for use with the lualine backend.
---@return table # lualine-compatible section config
function StatusBar:to_lualine()
    local function convert(sections)
        local result = {}
        for _, s in ipairs(sections) do
            result[#result + 1] = {
                function()
                    local text = s.provider()
                    return text or ''
                end,
                cond = s.cond,
            }
        end
        return result
    end

    return {
        lualine_a = convert(self._left),
        lualine_b = {},
        lualine_c = convert(self._center),
        lualine_x = {},
        lualine_y = {},
        lualine_z = convert(self._right),
    }
end

--- Get section count.
---@return integer
function StatusBar:section_count()
    return #self._left + #self._center + #self._right
end

---@return string
function StatusBar:__tostring()
    return string.format('StatusBar(%d sections)', self:section_count())
end

return StatusBar
