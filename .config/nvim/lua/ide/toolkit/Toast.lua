-- Toast: a temporary floating notification panel.
-- Renders a styled message with icon, title, timestamp, and auto-dismiss.
-- Uses reactive function component for content rendering.

local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'
local Timer = require 'ide.Timer'
local hooks = require 'ide.toolkit.hooks'
local C = require 'ide.toolkit.component'

local Toast = Class('Toast')

---@param opts { icon?: string, title?: string, body: string, hl?: string, border_hl?: string, width?: integer, timeout?: integer, row?: integer, col?: integer, on_dismiss?: fun() }
function Toast:init(opts)
    self._icon = opts.icon or ''
    self._title = opts.title or ''
    self._body = opts.body
    self._hl = opts.hl or 'Normal'
    self._border_hl = opts.border_hl or 'FloatBorder'
    self._width = opts.width or 60
    self._timeout = opts.timeout or 3000
    self._row = opts.row or 1
    self._col = opts.col or (Window.editor_width() - (opts.width or 60) - 2)
    self._on_dismiss = opts.on_dismiss
    self._buf = nil
    self._win = nil
    self._timer = nil
    self._component = nil
end

--- Function component for toast content.
local function ToastView(props)
    local timestamp = props.timestamp or ''
    local body_lines = vim.split(props.body or '', '\n')
    local children = {}

    -- Header: icon + title ... timestamp
    children[#children + 1] = {
        type = 'row',
        children = {
            { type = 'text', text = props.icon or '', hl = props.hl or 'Normal' },
            { type = 'text', text = ' ' .. (props.title or ''), hl = 'IDENotifyTitle' },
        },
    }

    -- Separator
    children[#children + 1] = { type = 'separator', char = '━', hl = props.hl or 'Normal' }

    -- Body
    for _, line in ipairs(body_lines) do
        children[#children + 1] = { type = 'text', text = line, hl = 'IDENotifyBody' }
    end

    return children
end

function Toast:show()
    local body_lines = vim.split(self._body, '\n')
    local height = 2 + #body_lines

    self._buf = Buffer.create({ listed = false, scratch = true })
    self._buf:set_option('bufhidden', 'wipe')

    -- Mount reactive component
    self._component = C.mount(ToastView, {
        icon = self._icon,
        title = self._title,
        body = self._body,
        hl = self._hl,
        timestamp = os.date('%H:%M:%S'),
    }, self._buf)

    self._win = Window.open_float(self._buf, {
        relative = 'editor',
        row = self._row,
        col = self._col,
        width = self._width,
        height = height,
        style = 'minimal',
        border = 'rounded',
        zindex = 175,
        focusable = false,
        noautocmd = true,
    })

    pcall(function()
        self._win:set_option('winblend', 5)
        self._win:set_option('winfixbuf', true)
        self._win:update_config({ border = {
            { '╭', self._border_hl }, { '─', self._border_hl }, { '╮', self._border_hl },
            { '│', self._border_hl }, { '╯', self._border_hl }, { '─', self._border_hl },
            { '╰', self._border_hl }, { '│', self._border_hl },
        }})
    end)

    if self._buf and self._buf:is_valid() then
        self._buf:bind_key('n', '<LeftMouse>', function() self:dismiss() end)
    end

    self._timer = Timer.delay(self._timeout, function()
        self:dismiss()
    end)

    return self
end

function Toast:dismiss()
    if self._timer then self._timer:stop(); self._timer = nil end
    if self._component then C.unmount(self._component); self._component = nil end
    if self._win and self._win:is_valid() then self._win:close(true) end
    if self._buf and self._buf:is_valid() then self._buf:close(true) end
    self._win = nil
    self._buf = nil
    if self._on_dismiss then self._on_dismiss() end
end

---@return boolean
function Toast:is_visible()
    return self._win ~= nil and self._win:is_valid()
end

---@return integer
function Toast:height()
    return self._buf and #vim.split(self._body, '\n') + 2 or 0
end

---@param row integer
---@param col integer
function Toast:reposition(row, col)
    self._row = row
    self._col = col
    if self._win and self._win:is_valid() then
        pcall(function()
            self._win:update_config({ relative = 'editor', row = row, col = col })
        end)
    end
end

---@return string
function Toast:__tostring()
    return string.format('Toast(%s)', self._title)
end

return Toast
