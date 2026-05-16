-- ProgressBar: TurboVision-style progress indicator.
-- Can be embedded in a Dialog or used standalone.
--
-- Usage:
--   local pb = ProgressBar({ label = 'Loading...', width = 30 })
--   pb:set_progress(0.5)  -- 50%
--   pb:render()  -- returns "Loading... [████████░░░░░░░░] 50%"

local ProgressBar = Class('ProgressBar')

---@param opts { label?: string, width?: integer, show_percent?: boolean }
function ProgressBar:init(opts)
    opts = opts or {}
    self._label = opts.label or ''
    self._width = opts.width or 20
    self._show_percent = opts.show_percent ~= false
    self._progress = 0
    self._focused = false
end

function ProgressBar:set_progress(value)
    self._progress = math.max(0, math.min(1, value))
end

function ProgressBar:progress()
    return self._progress
end

function ProgressBar:label()
    return self._label
end

function ProgressBar:focusable()
    return false
end

function ProgressBar:on_focus() self._focused = true end
function ProgressBar:on_blur() self._focused = false end
function ProgressBar:on_activate() end

function ProgressBar:render()
    local filled = math.floor(self._width * self._progress)
    local empty = self._width - filled
    local bar = string.rep('█', filled) .. string.rep('░', empty)
    local pct = self._show_percent and string.format(' %d%%', math.floor(self._progress * 100)) or ''
    local label = self._label ~= '' and (self._label .. ' ') or ''
    local text = label .. '[' .. bar .. ']' .. pct

    local highlights = {}
    local bar_start = #label + 1
    highlights[#highlights + 1] = {
        group = 'IDEDialogCheckMark',
        col_start = bar_start,
        col_end = bar_start + filled,
    }
    highlights[#highlights + 1] = {
        group = 'IDEDialogCheckbox',
        col_start = bar_start + filled,
        col_end = bar_start + filled + empty,
    }

    return text, highlights
end

function ProgressBar:__tostring()
    return string.format('ProgressBar(%d%%)', math.floor(self._progress * 100))
end

return ProgressBar
