-- RadioGroup: TurboVision-style exclusive radio button group.
-- Renders as ( ) Option1  (•) Option2 with &hotkey notation.
-- Only one option can be selected at a time.

local RadioGroup = Class('RadioGroup')

---@class RadioOption
---@field label string # Text with optional &hotkey: "&Dark"
---@field value any # Value returned when selected

---@class RadioGroupOpts
---@field options RadioOption[]
---@field selected? integer # 1-indexed default selection
---@field on_change? fun(value: any, index: integer)
---@field layout? 'vertical'|'horizontal' # default 'vertical'

---@param opts RadioGroupOpts
function RadioGroup:init(opts)
    self._options = opts.options or {}
    self._selected = opts.selected or 1
    self._on_change = opts.on_change
    self._layout = opts.layout or 'vertical'
    self._focused = false
    self._focus_idx = self._selected
end

function RadioGroup:label()
    if #self._options > 0 then
        return self._options[1].label
    end
    return ''
end

function RadioGroup:selected()
    return self._selected
end

function RadioGroup:selected_value()
    if self._options[self._selected] then
        return self._options[self._selected].value
    end
end

function RadioGroup:set_selected(index)
    if index >= 1 and index <= #self._options then
        self._selected = index
    end
end

function RadioGroup:focusable()
    return true
end

function RadioGroup:on_focus()
    self._focused = true
end

function RadioGroup:on_blur()
    self._focused = false
end

function RadioGroup:on_activate()
    self._selected = self._focus_idx
    if self._on_change and self._options[self._selected] then
        self._on_change(self._options[self._selected].value, self._selected)
    end
end

--- Move focus within the group.
---@param dir integer # +1 or -1
function RadioGroup:navigate(dir)
    self._focus_idx = self._focus_idx + dir
    if self._focus_idx > #self._options then self._focus_idx = 1 end
    if self._focus_idx < 1 then self._focus_idx = #self._options end
    self._selected = self._focus_idx
    if self._on_change and self._options[self._selected] then
        self._on_change(self._options[self._selected].value, self._selected)
    end
end

--- Parse & from label text.
local function parse_label(text)
    local pos = text:find('&')
    if not pos then return text, nil, nil end
    local display = text:sub(1, pos - 1) .. text:sub(pos + 1)
    local hotkey_pos = pos - 1
    return display, text:sub(pos + 1, pos + 1), hotkey_pos
end

--- Render all radio buttons.
---@return string, table[] # rendered text, highlight spans
function RadioGroup:render()
    local parts = {}
    local highlights = {}
    local offset = 0

    for i, opt in ipairs(self._options) do
        local bullet = i == self._selected and '(•)' or '( )'
        local display, hotkey_char, hotkey_pos = parse_label(opt.label)
        local entry = bullet .. ' ' .. display

        if self._layout == 'horizontal' and i > 1 then
            parts[#parts + 1] = '  '
            offset = offset + 2
        end

        -- Bullet highlight
        local bullet_hl = (self._focused and i == self._focus_idx) and 'IDEDialogFocused' or 'IDEDialogRadio'
        highlights[#highlights + 1] = { group = bullet_hl, col_start = offset, col_end = offset + 3 }

        -- Selected dot
        if i == self._selected then
            highlights[#highlights + 1] = { group = 'IDEDialogCheckMark', col_start = offset + 1, col_end = offset + 2 }
        end

        -- Hotkey underline
        if hotkey_pos then
            local hk_offset = offset + 4 + hotkey_pos
            highlights[#highlights + 1] = {
                group = 'IDEDialogHotkey',
                col_start = hk_offset,
                col_end = hk_offset + #(hotkey_char or ''),
            }
        end

        parts[#parts + 1] = entry
        offset = offset + #entry

        if self._layout == 'vertical' and i < #self._options then
            parts[#parts + 1] = '\n'
            offset = 0
        end
    end

    return table.concat(parts, ''), highlights
end

function RadioGroup:__tostring()
    local sel = self._options[self._selected]
    return string.format('RadioGroup(%d options, selected=%s)',
        #self._options, sel and sel.label or 'none')
end

return RadioGroup
