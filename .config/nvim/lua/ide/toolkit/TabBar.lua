-- TabBar: top tabline/bufferline abstraction.
-- Shows git branch, open buffers, and tabs.

local EventEmitter = require 'ide.EventEmitter'

local TabBar = Class('TabBar')
Class.include(TabBar, EventEmitter)

function TabBar:init()
    self._left = {}
    self._center = {}
    self._right = {}
end

---@param name string
---@param provider fun(): string, string|nil
---@param opts { cond?: fun(): boolean }|nil
---@return TabBar
function TabBar:left(name, provider, opts)
    opts = opts or {}
    self._left[#self._left + 1] = { name = name, provider = provider, cond = opts.cond }
    return self
end

---@param name string
---@param provider fun(): string, string|nil
---@param opts { cond?: fun(): boolean }|nil
---@return TabBar
function TabBar:center(name, provider, opts)
    opts = opts or {}
    self._center[#self._center + 1] = { name = name, provider = provider, cond = opts.cond }
    return self
end

---@param name string
---@param provider fun(): string, string|nil
---@param opts { cond?: fun(): boolean }|nil
---@return TabBar
function TabBar:right(name, provider, opts)
    opts = opts or {}
    self._right[#self._right + 1] = { name = name, provider = provider, cond = opts.cond }
    return self
end

--- Render to native tabline string.
---@return string
function TabBar:render()
    local parts = {}

    for _, s in ipairs(self._left) do
        if not s.cond or s.cond() then
            local text, hl = s.provider()
            if text and text ~= '' then
                parts[#parts + 1] = hl and string.format('%%#%s#%s%%*', hl, text) or text
            end
        end
    end

    parts[#parts + 1] = '%='

    for _, s in ipairs(self._center) do
        if not s.cond or s.cond() then
            local text, hl = s.provider()
            if text and text ~= '' then
                parts[#parts + 1] = hl and string.format('%%#%s#%s%%*', hl, text) or text
            end
        end
    end

    parts[#parts + 1] = '%='

    for _, s in ipairs(self._right) do
        if not s.cond or s.cond() then
            local text, hl = s.provider()
            if text and text ~= '' then
                parts[#parts + 1] = hl and string.format('%%#%s#%s%%*', hl, text) or text
            end
        end
    end

    return table.concat(parts, ' ')
end

--- Render a single named section.
---@param name string # section name registered via left/center/right
---@return string
function TabBar:render_section(name)
    for _, sections in ipairs({ self._left, self._center, self._right }) do
        for _, s in ipairs(sections) do
            if s.name == name and (not s.cond or s.cond()) then
                local text, hl = s.provider()
                if text and text ~= '' then
                    return hl and string.format('%%#%s#%s%%*', hl, text) or text
                end
            end
        end
    end
    return ''
end

--- Apply as native tabline.
function TabBar:apply_native()
    local Dispatch = require 'ide.Dispatch'
    Dispatch.renderer('tabbar', function() return self:render() end)
    vim.o.showtabline = 2
    vim.o.tabline = '%!v:lua.IDE_render_tabbar()'
end

--- Convert to lualine format.
---@return table
function TabBar:to_lualine()
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
        lualine_b = convert(self._center),
        lualine_c = {},
        lualine_x = {},
        lualine_y = {},
        lualine_z = convert(self._right),
    }
end

---@return string
function TabBar:__tostring()
    return string.format('TabBar(%d sections)',
        #self._left + #self._center + #self._right)
end

return TabBar
