-- Button: TurboVision-style clickable button.
-- Renders as [ OK ] or [ Cancel ] with &hotkey notation.
-- Activates on Enter, Space, or hotkey press.

local Button = Class('Button')

---@class ButtonOpts
---@field label string # Button text with optional &hotkey: "&OK", "&Cancel"
---@field action? fun() # Called when button is activated
---@field style? 'default'|'primary' # Primary buttons are highlighted

---@param opts ButtonOpts
function Button:init(opts)
    self._label = opts.label or 'OK'
    self._action = opts.action
    self._style = opts.style or 'default'
    self._focused = false
end

function Button:label()
    return self._label
end

function Button:focusable()
    return true
end

function Button:on_focus()
    self._focused = true
end

function Button:on_blur()
    self._focused = false
end

function Button:on_activate()
    if self._action then
        self._action()
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

--- Render the button as text + highlight info.
---@return string, table[] # rendered text, highlight spans
function Button:render()
    local display, hotkey_char, hotkey_pos = parse_label(self._label)
    local text = '[ ' .. display .. ' ]'

    local highlights = {}

    -- Button frame highlight
    local hl
    if self._focused then
        hl = 'IDEDialogButtonFocused'
    elseif self._style == 'primary' then
        hl = 'IDEDialogButtonPrimary'
    else
        hl = 'IDEDialogButton'
    end
    highlights[#highlights + 1] = { group = hl, col_start = 0, col_end = #text }

    -- Hotkey underline (position offset by "[ " prefix = 2)
    if hotkey_pos then
        local offset = 2 + hotkey_pos
        highlights[#highlights + 1] = {
            group = 'IDEDialogHotkey',
            col_start = offset,
            col_end = offset + #(hotkey_char or ''),
        }
    end

    return text, highlights
end

function Button:__tostring()
    return string.format('Button([ %s ])', self._label)
end

return Button
