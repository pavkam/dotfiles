-- Checkbox: TurboVision-style toggleable checkbox.
-- Renders as [x] Label or [ ] Label with &hotkey notation.
-- When toggled, calls on_change callback with new state.

local Checkbox = Class('Checkbox')

---@class CheckboxOpts
---@field label string # Text with optional &hotkey: "&Enable spell checking"
---@field checked? boolean
---@field on_change? fun(checked: boolean)

---@param opts CheckboxOpts
function Checkbox:init(opts)
    self._label = opts.label or ''
    self._checked = opts.checked or false
    self._on_change = opts.on_change
    self._focused = false
end

function Checkbox:label()
    return self._label
end

function Checkbox:checked()
    return self._checked
end

function Checkbox:set_checked(value)
    self._checked = value
end

function Checkbox:focusable()
    return true
end

function Checkbox:on_focus()
    self._focused = true
end

function Checkbox:on_blur()
    self._focused = false
end

function Checkbox:on_activate()
    self._checked = not self._checked
    if self._on_change then
        self._on_change(self._checked)
    end
end

--- Parse & from label for display.
local function parse_label(text)
    local pos = text:find('&')
    if not pos then return text, nil, nil end
    local display = text:sub(1, pos - 1) .. text:sub(pos + 1)
    local hotkey_pos = pos - 1  -- 0-indexed position in display
    return display, text:sub(pos + 1, pos + 1), hotkey_pos
end

--- Render the checkbox as text + highlight info.
---@return string, table[] # rendered text, highlight spans
function Checkbox:render()
    local box = self._checked and '[x]' or '[ ]'
    local display, hotkey_char, hotkey_pos = parse_label(self._label)
    local text = box .. ' ' .. display

    local highlights = {}

    -- Box highlight
    local box_hl = self._focused and 'IDEDialogFocused' or 'IDEDialogCheckbox'
    highlights[#highlights + 1] = { group = box_hl, col_start = 0, col_end = 3 }

    -- Check mark
    if self._checked then
        highlights[#highlights + 1] = { group = 'IDEDialogCheckMark', col_start = 1, col_end = 2 }
    end

    -- Hotkey underline
    if hotkey_pos then
        local offset = 4 + hotkey_pos  -- 4 = "[x] "
        highlights[#highlights + 1] = {
            group = 'IDEDialogHotkey',
            col_start = offset,
            col_end = offset + #(hotkey_char or ''),
        }
    end

    return text, highlights
end

function Checkbox:__tostring()
    local box = self._checked and '[x]' or '[ ]'
    return string.format('Checkbox(%s %s)', box, self._label)
end

return Checkbox
