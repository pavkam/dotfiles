-- MessageBox: TurboVision-style modal dialog for confirmations,
-- warnings, and errors. Shows a message with icon and action buttons.
--
-- Usage:
--   MessageBox.confirm('Save changes?', function(yes) ... end)
--   MessageBox.info('Operation complete')
--   MessageBox.error('Something went wrong')

local Dialog = require 'ide.toolkit.Dialog'
local Button = require 'ide.toolkit.Button'

local MessageBox = Class('MessageBox')

---@class MessageBoxOpts
---@field title? string
---@field message string
---@field icon? string # ⚠ ❌ ℹ ❓
---@field buttons? { label: string, action?: fun(), style?: string }[]
---@field on_close? fun()

---@param opts MessageBoxOpts
function MessageBox:init(opts)
    self._title = opts.title or 'Message'
    self._message = opts.message or ''
    self._icon = opts.icon
    self._buttons = opts.buttons or { { label = '&OK', style = 'primary' } }
    self._on_close = opts.on_close
    self._dialog = nil
end

function MessageBox:show()
    local lines = vim.split(self._message, '\n')
    local max_line = 0
    for _, l in ipairs(lines) do
        if #l > max_line then max_line = #l end
    end

    local icon_width = self._icon and 4 or 0
    local width = math.max(max_line + icon_width + 6, 24)

    -- Button row width
    local btn_total = 0
    for _, b in ipairs(self._buttons) do
        local display = b.label:gsub('&', '')
        btn_total = btn_total + #display + 6  -- [ label ] + gap
    end
    width = math.max(width, btn_total + 4)

    local height = #lines + 5  -- message + spacer + buttons + padding

    self._dialog = Dialog({
        title = self._title,
        width = width,
        height = height,
        shadow = true,
        on_close = self._on_close,
    })

    -- Add icon + message as static text (not focusable widgets)
    -- We'll render them in the dialog content directly

    -- Add buttons
    local btn_start = math.floor((width - btn_total) / 2)
    local col = btn_start
    for _, b in ipairs(self._buttons) do
        local dlg = self._dialog
        self._dialog:add_widget(Button({
            label = b.label,
            style = b.style or 'default',
            action = function()
                dlg:close()
                if b.action then vim.schedule(b.action) end
            end,
        }), #lines + 3, col)
        local display = b.label:gsub('&', '')
        col = col + #display + 6
    end

    -- Render message text into the dialog via Canvas before showing
    local Canvas = require 'ide.toolkit.Canvas'
    local c = Canvas(width, #lines + 1)
    for i, line in ipairs(lines) do
        local text = (self._icon and i == 1) and (self._icon .. '  ' .. line) or ('    ' .. line)
        local hl = (self._icon and i == 1) and 'IDEDialogTitle' or 'IDEDialogNormal'
        c:text(i, 1, text, hl)
    end

    self._dialog:show()

    if self._dialog:buffer() and self._dialog:buffer():is_valid() then
        c:render(self._dialog:buffer())
    end
end

function MessageBox:close()
    if self._dialog then self._dialog:close() end
end

-- ── Convenience constructors ────────────────────────────────────

function MessageBox.info(message, on_ok)
    MessageBox({
        title = 'Information',
        message = message,
        icon = 'ℹ',
        buttons = { { label = '&OK', style = 'primary', action = on_ok } },
    }):show()
end

function MessageBox.warn(message, on_ok)
    MessageBox({
        title = 'Warning',
        message = message,
        icon = '⚠',
        buttons = { { label = '&OK', style = 'primary', action = on_ok } },
    }):show()
end

function MessageBox.error(message, on_ok)
    MessageBox({
        title = 'Error',
        message = message,
        icon = '❌',
        buttons = { { label = '&OK', style = 'primary', action = on_ok } },
    }):show()
end

function MessageBox.confirm(message, on_result)
    MessageBox({
        title = 'Confirm',
        message = message,
        icon = '❓',
        buttons = {
            { label = '&Yes', style = 'primary', action = function() on_result(true) end },
            { label = '&No', action = function() on_result(false) end },
            { label = '&Cancel', action = function() on_result(nil) end },
        },
    }):show()
end

function MessageBox.yesno(message, on_result)
    MessageBox({
        title = 'Confirm',
        message = message,
        icon = '❓',
        buttons = {
            { label = '&Yes', style = 'primary', action = function() on_result(true) end },
            { label = '&No', action = function() on_result(false) end },
        },
    }):show()
end

function MessageBox:__tostring()
    return string.format('MessageBox(%s)', self._title)
end

return MessageBox
