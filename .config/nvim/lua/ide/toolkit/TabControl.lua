-- TabControl: TurboVision-style tabbed panel widget.
-- Shows tab headers at the top with switchable content areas.
-- Each tab hosts different widgets. Left/Right switches tabs.
--
-- Rendering:
--   ┌─Editor─┐ ┌─LSP─┐ ┌─Theme─┐
--   │ content area for active tab  │
--   └─────────────────────────────┘

local TabControl = Class('TabControl')

---@class TabDef
---@field label string # tab title with optional &hotkey
---@field widgets table[] # { widget, row, col } entries for this tab

---@class TabControlOpts
---@field tabs TabDef[]
---@field selected? integer
---@field width? integer
---@field on_change? fun(index: integer, label: string)

---@param opts TabControlOpts
function TabControl:init(opts)
    self._tabs = opts.tabs or {}
    self._selected = opts.selected or 1
    self._width = opts.width or 40
    self._on_change = opts.on_change
    self._focused = false
end

function TabControl:label()
    if #self._tabs > 0 then return self._tabs[1].label end
    return ''
end

function TabControl:focusable()
    return true
end

function TabControl:on_focus()
    self._focused = true
end

function TabControl:on_blur()
    self._focused = false
end

function TabControl:on_activate()
    self._selected = self._selected + 1
    if self._selected > #self._tabs then self._selected = 1 end
    if self._on_change and self._tabs[self._selected] then
        self._on_change(self._selected, self._tabs[self._selected].label)
    end
end

function TabControl:selected()
    return self._selected
end

function TabControl:set_selected(index)
    if index >= 1 and index <= #self._tabs then
        self._selected = index
    end
end

function TabControl:active_tab()
    return self._tabs[self._selected]
end

--- Parse & from label text.
local function strip_hotkey(text)
    return text:gsub('&', '')
end

--- Render the tab headers as a single line.
---@return string, table[]
function TabControl:render()
    local parts = {}
    local highlights = {}
    local offset = 0

    for i, tab in ipairs(self._tabs) do
        local display = strip_hotkey(tab.label)
        local is_active = i == self._selected

        if is_active then
            local header = '┌─' .. display .. '─┐'
            parts[#parts + 1] = header
            highlights[#highlights + 1] = {
                group = self._focused and 'IDEDialogFocused' or 'IDEDialogTitle',
                col_start = offset,
                col_end = offset + #header,
            }
            offset = offset + #header
        else
            local header = ' ' .. display .. ' '
            parts[#parts + 1] = header
            highlights[#highlights + 1] = {
                group = 'IDEDialogCheckbox',
                col_start = offset,
                col_end = offset + #header,
            }
            offset = offset + #header
        end

        if i < #self._tabs then
            parts[#parts + 1] = ' '
            offset = offset + 1
        end
    end

    return table.concat(parts), highlights
end

function TabControl:__tostring()
    local active = self._tabs[self._selected]
    return string.format('TabControl(%d tabs, active=%s)',
        #self._tabs, active and strip_hotkey(active.label) or 'none')
end

return TabControl
