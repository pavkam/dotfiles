-- Notifications Extension: owned notification rendering.
-- Replaces nvim-notify with Toast toolkit components.
-- Uses fixed highlight groups (never per-buffer) — prevents E849.

local Extension = require 'ide.Extension'
local Window = require 'ide.Window'
local Timer = require 'ide.Timer'
local Toast = require 'ide.toolkit.Toast'
local Panel = require 'ide.toolkit.Panel'

local Notifications = Class('Notifications', Extension)

local MAX_VISIBLE = 3
local DEFAULT_TIMEOUT = 3000
local WIDTH = 60
local PADDING_RIGHT = 2
local PADDING_TOP = 1
local SPACING = 1
local LONG_MESSAGE_LINES = 10

local LEVEL_CONFIG = {
    [vim.log.levels.INFO]  = { icon = ' ', hl = 'IDENotifyInfo',  border_hl = 'IDENotifyInfoBorder',  title = 'Info' },
    [vim.log.levels.WARN]  = { icon = ' ', hl = 'IDENotifyWarn',  border_hl = 'IDENotifyWarnBorder',  title = 'Warning' },
    [vim.log.levels.ERROR] = { icon = ' ', hl = 'IDENotifyError', border_hl = 'IDENotifyErrorBorder', title = 'Error' },
    [vim.log.levels.DEBUG] = { icon = ' ', hl = 'IDENotifyDebug', border_hl = 'IDENotifyDebugBorder', title = 'Debug' },
}

function Notifications:init()
    Extension.init(self, 'Notifications')
    self._visible = {}
    self._queue = {}
end

function Notifications:_define_highlights()
    IDE.theme:define('IDENotifyInfo', { fg = '#7dcfff', bold = true, default = true })
    IDE.theme:define('IDENotifyWarn', { fg = '#e0af68', bold = true, default = true })
    IDE.theme:define('IDENotifyError', { fg = '#f7768e', bold = true, default = true })
    IDE.theme:define('IDENotifyDebug', { fg = '#9d7cd8', bold = true, default = true })
    IDE.theme:define('IDENotifyInfoBorder', { fg = '#3d59a1', default = true })
    IDE.theme:define('IDENotifyWarnBorder', { fg = '#e0af68', default = true })
    IDE.theme:define('IDENotifyErrorBorder', { fg = '#f7768e', default = true })
    IDE.theme:define('IDENotifyDebugBorder', { fg = '#9d7cd8', default = true })
    IDE.theme:define('IDENotifyBody', { fg = '#c0caf5', default = true })
    IDE.theme:define('IDENotifyTitle', { fg = '#c0caf5', bold = true, default = true })
    IDE.theme:define('IDENotifyTimestamp', { fg = '#565f89', default = true })
end

function Notifications:_calc_row(index)
    local row = PADDING_TOP
    for i = 1, index - 1 do
        local toast = self._visible[i]
        if toast and toast:is_visible() then
            row = row + toast:height() + SPACING
        end
    end
    return row
end

function Notifications:_reposition()
    local col = Window.editor_width() - WIDTH - PADDING_RIGHT
    for i, toast in ipairs(self._visible) do
        if toast:is_visible() then
            toast:reposition(self:_calc_row(i), col)
        end
    end
end

function Notifications:_remove(toast)
    for i, t in ipairs(self._visible) do
        if t == toast then
            table.remove(self._visible, i)
            break
        end
    end
    self:_reposition()
    self:_process_queue()
end

function Notifications:show(msg, level, opts)
    level = level or vim.log.levels.INFO
    if level == vim.log.levels.DEBUG then return end
    if self._startup_suppressed then return end

    -- Long messages open in a Panel instead of a Toast
    local line_count = select(2, msg:gsub('\n', '\n')) + 1
    if line_count >= LONG_MESSAGE_LINES then
        self:_show_panel(msg, level, opts)
        return
    end

    if #self._visible >= MAX_VISIBLE then
        self._queue[#self._queue + 1] = { msg = msg, level = level, opts = opts }
        return
    end
    self:_show_toast(msg, level, opts)
end

function Notifications:_show_toast(msg, level, opts)
    opts = opts or {}
    local cfg = LEVEL_CONFIG[level] or LEVEL_CONFIG[vim.log.levels.INFO]
    local col = Window.editor_width() - WIDTH - PADDING_RIGHT
    local row = self:_calc_row(#self._visible + 1)

    local ext = self
    local toast = Toast({
        icon = cfg.icon,
        title = opts.title or cfg.title,
        body = msg,
        hl = cfg.hl,
        border_hl = cfg.border_hl,
        width = WIDTH,
        timeout = opts.timeout or DEFAULT_TIMEOUT,
        row = row,
        col = col,
        on_dismiss = function()
            ext:_remove(toast)
        end,
    })

    self._visible[#self._visible + 1] = toast
    toast:show()
end

function Notifications:_show_panel(msg, level, opts)
    opts = opts or {}
    local cfg = LEVEL_CONFIG[level] or LEVEL_CONFIG[vim.log.levels.INFO]
    local title = (cfg.icon or '') .. ' ' .. (opts.title or cfg.title or 'Notification')
    local body_lines = vim.split(msg, '\n')
    local height = math.min(#body_lines + 2, math.floor(Window.editor_height() * 0.7))

    local panel = Panel({
        title = title,
        width = 0.6,
        height = height,
        border = 'rounded',
    })
    panel:show()
    panel:set_lines(body_lines)
end

function Notifications:_process_queue()
    while #self._visible < MAX_VISIBLE and #self._queue > 0 do
        local item = table.remove(self._queue, 1)
        self:_show_toast(item.msg, item.level, item.opts)
    end
end

function Notifications:dismiss_all()
    for _, toast in ipairs(self._visible) do
        toast:dismiss()
    end
    self._visible = {}
    self._queue = {}
end

--- Level integer to human-readable name.
---@param level integer
---@return string
local function level_name(level)
    if level == vim.log.levels.INFO then return 'info'
    elseif level == vim.log.levels.WARN then return 'warn'
    elseif level == vim.log.levels.ERROR then return 'error'
    elseif level == vim.log.levels.DEBUG then return 'debug'
    end
    return 'info'
end

--- Show the notification history in a SearchableList.
function Notifications:_show_history()
    local SearchableList = require 'ide.toolkit.SearchableList'
    local history = IDE.notify:history()
    if #history == 0 then
        IDE.notify:info('No notifications in history')
        return
    end

    local HistoryList = Class('HistoryList', SearchableList)

    function HistoryList:init(entries)
        SearchableList.init(self, {
            title = 'Notification History',
            width = 0.7,
            height = 0.6,
        })
        self._entries = entries
        self._filtered = entries
    end

    function HistoryList:items() return self._filtered end
    function HistoryList:total_count() return #self._entries end

    function HistoryList:on_query_change(query)
        if query == '' then
            self._filtered = self._entries
            return
        end
        local q = query:lower()
        self._filtered = {}
        for _, entry in ipairs(self._entries) do
            local text = (entry.message .. ' ' .. (entry.title or '')):lower()
            if text:find(q, 1, true) then
                self._filtered[#self._filtered + 1] = entry
            end
        end
        self._selected = 1
        self._scroll = 0
    end

    function HistoryList:render_item(item, width)
        local cfg = LEVEL_CONFIG[item.level] or LEVEL_CONFIG[vim.log.levels.INFO]
        local time_str = os.date('%H:%M:%S', item.timestamp)
        local icon = cfg.icon or ' '
        local hl = cfg.hl or 'IDENotifyInfo'

        local first_line = vim.split(item.message, '\n')[1] or ''
        local max_msg = width - 20
        if IDE.text:display_width(first_line) > max_msg then
            first_line = first_line:sub(1, max_msg - 1) .. '…'
        end
        return {
            { type = 'text', text = time_str .. '  ', hl = 'IDENotifyTimestamp' },
            { type = 'text', text = icon .. ' ', hl = hl },
            { type = 'text', text = first_line, hl = 'IDENotifyBody' },
        }
    end

    function HistoryList:on_submit(item)
        -- Show the full message in a Panel
        local cfg = LEVEL_CONFIG[item.level] or LEVEL_CONFIG[vim.log.levels.INFO]
        local title = (cfg.icon or '') .. ' ' .. (item.title or cfg.title or 'Notification')
            .. '  ' .. os.date('%Y-%m-%d %H:%M:%S', item.timestamp)
        local body_lines = vim.split(item.message, '\n')
        local height = math.min(#body_lines + 2, math.floor(Window.editor_height() * 0.7))

        local panel = Panel({
            title = title,
            width = 0.6,
            height = math.max(height, 5),
            border = 'rounded',
        })
        panel:show()
        panel:set_lines(body_lines)
    end

    HistoryList(history):show()
end

function Notifications:on_register(ctx)
    self:_define_highlights()
    self._startup_suppressed = true
    Timer.delay(500, function()
        self._startup_suppressed = false
    end)

    local ext = self
    ctx:command('IDEDismissNotifications', function() self:dismiss_all() end, { desc = 'Dismiss all notifications' })
    ctx:command('IDENotificationHistory', function() ext:_show_history() end, { desc = 'Show notification history' })

    -- Add to View menu
    if IDE.menu_bar then
        local MenuItem = require 'ide.toolkit.MenuItem'
        IDE.menu_bar:add_item('View', MenuItem({
            text = 'Notification History', icon = '󰋚',
            action = function() ext:_show_history() end,
        }))
    end
end

return Notifications
