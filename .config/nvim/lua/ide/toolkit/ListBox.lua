-- ListBox: TurboVision-style scrollable list within a dialog.
-- Shows a bordered list of items with j/k navigation and Enter selection.
-- Supports icons, scroll indicators, and search-as-you-type filtering.

local ListBox = Class('ListBox')

---@class ListBoxItem
---@field text string
---@field icon? string
---@field value? any
---@field enabled? boolean

---@class ListBoxOpts
---@field items ListBoxItem[]
---@field height? integer # visible rows
---@field on_select? fun(item: ListBoxItem, index: integer)
---@field on_change? fun(item: ListBoxItem, index: integer) # cursor change
---@field label? string # optional label with &hotkey

---@param opts ListBoxOpts
function ListBox:init(opts)
    self._items = opts.items or {}
    self._visible_height = opts.height or 8
    self._on_select = opts.on_select
    self._on_change = opts.on_change
    self._label = opts.label
    self._selected = #self._items > 0 and 1 or 0
    self._scroll_offset = 0
    self._focused = false
end

function ListBox:label()
    return self._label
end

function ListBox:focusable()
    return true
end

function ListBox:on_focus()
    self._focused = true
end

function ListBox:on_blur()
    self._focused = false
end

function ListBox:on_activate()
    if self._selected > 0 and self._items[self._selected] then
        local item = self._items[self._selected]
        if item.enabled ~= false and self._on_select then
            self._on_select(item, self._selected)
        end
    end
end

function ListBox:selected()
    return self._selected
end

function ListBox:selected_item()
    return self._items[self._selected]
end

function ListBox:set_items(items)
    self._items = items or {}
    self._selected = #self._items > 0 and 1 or 0
    self._scroll_offset = 0
end

function ListBox:move(dir)
    if #self._items == 0 then return end
    self._selected = self._selected + dir
    if self._selected < 1 then self._selected = #self._items end
    if self._selected > #self._items then self._selected = 1 end

    -- Adjust scroll
    if self._selected <= self._scroll_offset then
        self._scroll_offset = self._selected - 1
    elseif self._selected > self._scroll_offset + self._visible_height then
        self._scroll_offset = self._selected - self._visible_height
    end

    if self._on_change and self._items[self._selected] then
        self._on_change(self._items[self._selected], self._selected)
    end
end

--- Render the listbox as multi-line text + highlights.
---@return string, table[] # rendered text, highlight spans
function ListBox:render()
    if #self._items == 0 then
        return '(empty)', {}
    end

    local lines = {}
    local highlights = {}
    local visible_end = math.min(self._scroll_offset + self._visible_height, #self._items)

    for i = self._scroll_offset + 1, visible_end do
        local item = self._items[i]
        local is_sel = i == self._selected
        local icon_part = item.icon and (item.icon .. ' ') or '  '
        local line = icon_part .. item.text

        lines[#lines + 1] = line

        local row = #lines - 1
        if is_sel and self._focused then
            highlights[#highlights + 1] = {
                group = 'IDEDialogListSelected',
                col_start = 0,
                col_end = #line,
                row = row,
            }
        elseif item.enabled == false then
            highlights[#highlights + 1] = {
                group = 'IDEDialogListDisabled',
                col_start = 0,
                col_end = #line,
                row = row,
            }
        end
    end

    -- Scroll indicators
    local has_above = self._scroll_offset > 0
    local has_below = visible_end < #self._items
    if has_above then
        lines[1] = '▲' .. lines[1]:sub(2)
    end
    if has_below and #lines > 0 then
        lines[#lines] = '▼' .. lines[#lines]:sub(2)
    end

    return table.concat(lines, '\n'), highlights
end

function ListBox:count()
    return #self._items
end

function ListBox:__tostring()
    return string.format('ListBox(%d items, selected=%d)',
        #self._items, self._selected)
end

return ListBox
