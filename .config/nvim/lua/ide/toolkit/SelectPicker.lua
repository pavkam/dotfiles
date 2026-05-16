-- SelectPicker: general-purpose item selection dialog.
-- Extends SearchableList with fuzzy filtering over a static item list.

local SearchableList = require 'ide.toolkit.SearchableList'

local SelectPicker = Class('SelectPicker', SearchableList)

---@param opts { title?: string, items: table[], on_select?: fun(item: table), width?: number, height?: number }
function SelectPicker:init(opts)
    opts = opts or {}
    local item_count = #opts.items
    SearchableList.init(self, {
        title = opts.title or '  Select',
        width = opts.width or 0.4,
        height = opts.height or math.min(item_count + 4, 20),
        on_select = opts.on_select,
    })
    self._all_items = opts.items
    self._filtered = opts.items
end

function SelectPicker:items()
    return self._filtered
end

function SelectPicker:total_count()
    return #self._all_items
end

function SelectPicker:on_query_change(query)
    if query == '' then
        self._filtered = self._all_items
    else
        local q = query:lower()
        self._filtered = {}
        for _, item in ipairs(self._all_items) do
            local text = (item.text or item.name or tostring(item)):lower()
            if text:find(q, 1, true) then
                self._filtered[#self._filtered + 1] = item
            end
        end
    end
    self._selected = 1
    self._scroll = 0
end

function SelectPicker:render_item(canvas, row, item, width)
    local icon_part = item.icon and (item.icon .. ' ') or '  '
    canvas:text(row, 2, icon_part .. (item.text or item.name or tostring(item)))
    if item.hint then
        canvas:right(row, item.hint .. ' ')
    end
end

function SelectPicker:__tostring()
    return string.format('SelectPicker(%s, %d items)', self._title, #self._all_items)
end

return SelectPicker
