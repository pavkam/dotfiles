-- ComboBox: TurboVision-style dropdown selection widget.
-- Shows current value with ▼ indicator. On activate, drops down a list.
-- Used for non-boolean settings in dialogs.
--
-- Rendering: [ Current Value ▼ ]

local ComboBox = Class('ComboBox')

---@class ComboBoxOpts
---@field label? string # optional label with &hotkey
---@field options string[] # list of option values
---@field selected? integer # 1-indexed default
---@field on_change? fun(value: string, index: integer)

---@param opts ComboBoxOpts
function ComboBox:init(opts)
    self._label = opts.label
    self._options = opts.options or {}
    self._selected = opts.selected or 1
    self._on_change = opts.on_change
    self._focused = false
end

function ComboBox:label()
    return self._label
end

function ComboBox:selected()
    return self._selected
end

function ComboBox:selected_value()
    return self._options[self._selected]
end

function ComboBox:set_selected(index)
    if index >= 1 and index <= #self._options then
        self._selected = index
    end
end

function ComboBox:focusable()
    return true
end

function ComboBox:on_focus()
    self._focused = true
end

function ComboBox:on_blur()
    self._focused = false
end

function ComboBox:on_activate()
    -- Cycle to next option
    self._selected = self._selected + 1
    if self._selected > #self._options then self._selected = 1 end
    if self._on_change and self._options[self._selected] then
        self._on_change(self._options[self._selected], self._selected)
    end
end

--- Parse & from label text.
local function parse_label(text)
    if not text then return '', nil, nil end
    local pos = text:find('&')
    if not pos then return text, nil, nil end
    local display = text:sub(1, pos - 1) .. text:sub(pos + 1)
    local hotkey_pos = pos - 1
    return display, text:sub(pos + 1, pos + 1), hotkey_pos
end

--- Render the combo box as text + highlight info.
---@return string, table[]
function ComboBox:render()
    local value = self._options[self._selected] or '(none)'
    local box = '[ ' .. value .. ' ▼ ]'

    local highlights = {}
    local hl = self._focused and 'IDEDialogFocused' or 'IDEDialogButton'
    highlights[#highlights + 1] = { group = hl, col_start = 0, col_end = #box }

    local text = box
    if self._label then
        local display, hotkey_char, hotkey_pos = parse_label(self._label)
        text = display .. ': ' .. box
        if hotkey_pos then
            highlights[#highlights + 1] = {
                group = 'IDEDialogHotkey',
                col_start = hotkey_pos,
                col_end = hotkey_pos + #(hotkey_char or ''),
            }
        end
    end

    return text, highlights
end

function ComboBox:__tostring()
    return string.format('ComboBox(%d options, selected=%s)',
        #self._options, self._options[self._selected] or 'none')
end

return ComboBox
