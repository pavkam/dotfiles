-- List: interactive list component.
-- A floating panel with selectable items, column layout, and rich rendering.
-- Uses a reactive function component for content rendering.

local Panel = require 'ide.toolkit.Panel'
local hooks = require 'ide.toolkit.hooks'
local C = require 'ide.toolkit.component'

local List = Class('List', Panel)

---@param opts { title?: string, items: table[], columns?: { key: string, hl?: string|fun(item:table):string, width?: integer }[], on_select?: fun(item: table, idx: integer), width?: number, height?: number }
function List:init(opts)
    Panel.init(self, {
        title = opts.title or 'Select',
        width = opts.width or 0.5,
        height = opts.height or 0.4,
        enter = true,
    })
    self._items = opts.items or {}
    self._columns = opts.columns
    self._on_select = opts.on_select
end

--- Function component for the list content.
local function ListView(props)
    local items = props.items or {}
    local columns = props.columns
    local selected, setSelected = hooks.useState(1)
    local height = props.height or 20

    -- Expose state for external keybinds
    props._state = { selected = selected, setSelected = setSelected }

    -- Clamp selection
    local sel = math.max(1, math.min(selected, #items))
    if sel ~= selected then setSelected(sel) end

    local children = {}

    if #items == 0 then
        children[#children + 1] = { type = 'text', text = '  No items', indent = 1, hl = 'IDEPanelDim' }
        return children
    end

    local visible = math.min(#items, height)
    for i = 1, visible do
        local item = items[i]
        if not item then break end

        if columns then
            local parts = {}
            local col_pos = 0
            for ci, col in ipairs(columns) do
                local val = tostring(item[col.key] or '')
                local hl = col.hl or 'Normal'
                if type(hl) == 'function' then hl = hl(item) or 'Normal' end
                parts[#parts + 1] = { type = 'text', text = val, hl = hl }
                if ci < #columns then
                    parts[#parts + 1] = { type = 'text', text = '  ', hl = 'Normal' }
                end
            end

            if i == sel then
                children[#children + 1] = { type = 'row', hl = 'IDEPanelSelected', children = parts }
            else
                children[#children + 1] = { type = 'row', children = parts }
            end
        else
            local text = item.text or item.name or item[1] or tostring(item)
            local hl = item.hl or 'Normal'
            if i == sel then
                children[#children + 1] = {
                    type = 'row', hl = 'IDEPanelSelected',
                    children = { { type = 'text', text = '▸ ' .. text, indent = 0, hl = 'IDEPanelSelected' } },
                }
            else
                children[#children + 1] = { type = 'text', text = '  ' .. text, hl = hl }
            end
        end
    end

    -- Status bar
    children[#children + 1] = {
        type = 'status',
        text = string.format('%d/%d ', sel, #items),
        hl = 'IDEPanelDim',
        text_hl = 'IDEPanelCounter',
    }

    return children
end

function List:_on_mount()
    local list = self
    self._component = C.mount(ListView, {
        items = self._items,
        columns = self._columns,
        height = self._current_height or 20,
        _state = {},
    }, self:buffer(), self._win)

    local function state()
        return self._component and self._component.ctx.props._state or {}
    end

    -- Navigation
    self:map('n', 'j', function()
        local s = state()
        if s.setSelected then
            s.setSelected(math.min((s.selected or 1) + 1, #self._items))
        end
    end)
    self:map('n', 'k', function()
        local s = state()
        if s.setSelected then
            s.setSelected(math.max((s.selected or 1) - 1, 1))
        end
    end)
    self:map('n', '<Down>', function()
        local s = state()
        if s.setSelected then
            s.setSelected(math.min((s.selected or 1) + 1, #self._items))
        end
    end)
    self:map('n', '<Up>', function()
        local s = state()
        if s.setSelected then
            s.setSelected(math.max((s.selected or 1) - 1, 1))
        end
    end)
    self:map('n', 'G', function()
        local s = state()
        if s.setSelected then s.setSelected(#self._items) end
    end)
    self:map('n', 'gg', function()
        local s = state()
        if s.setSelected then s.setSelected(1) end
    end)

    -- Selection
    self:map('n', '<CR>', function()
        local s = state()
        local item = self._items[s.selected or 1]
        if item and list._on_select then
            list:hide()
            vim.schedule(function()
                list._on_select(item, s.selected or 1)
            end)
        end
    end)
end

function List:hide()
    if self._component then
        C.unmount(self._component)
        self._component = nil
    end
    Panel.hide(self)
end

--- Update items and re-render.
---@param items table[]
function List:set_items(items)
    self._items = items
    if self._component then
        C.update(self._component, {
            items = items,
            columns = self._columns,
            height = self._current_height or 20,
            _state = {},
        })
    end
end

---@return string
function List:__tostring()
    return string.format('List(%s, %d items)', self._title, #self._items)
end

return List
