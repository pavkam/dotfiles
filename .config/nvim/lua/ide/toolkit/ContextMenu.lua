-- ContextMenu: right-click context menu with rounded borders.
-- Positions at mouse click, shows context-aware actions.
-- Uses reactive function component for content rendering.

local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'
local Shadow = require 'ide.toolkit.Shadow'
local hooks = require 'ide.toolkit.hooks'
local C = require 'ide.toolkit.component'

local ContextMenu = Class('ContextMenu')

---@class ContextMenuItem
---@field text string
---@field icon string|nil
---@field action fun()
---@field separator boolean|nil
---@field hl string|nil

---@param items ContextMenuItem[]
---@param opts { title?: string }|nil
function ContextMenu:init(items, opts)
    opts = opts or {}
    self._items = items
    self._title = opts.title
    self._buf = nil
    self._win = nil
    self._shadow = nil
    self._component = nil
    self._action_map = {}
end

--- Function component for menu content.
local function ContextMenuView(props)
    local items = props.items or {}
    local width = props.width or 30
    local selected, setSelected = hooks.useState(props.initial_selected or 1)

    props._state = { selected = selected, setSelected = setSelected }

    local children = {}
    for i, item in ipairs(items) do
        if item.separator then
            children[#children + 1] = { type = 'separator', hl = 'IDEMenuSeparator' }
        else
            local label = (item.icon or '  ') .. ' ' .. item.text
            if i == selected then
                children[#children + 1] = {
                    type = 'row', hl = 'IDEMenuItemSelected',
                    children = { { type = 'text', text = label, hl = 'IDEMenuItemSelected' } },
                }
            else
                children[#children + 1] = {
                    type = 'text', text = label, hl = item.hl or 'IDEMenuItemNormal',
                }
            end
        end
    end

    return children
end

function ContextMenu:show()
    local mouse = vim.fn.getmousepos()
    if not mouse or mouse.screenrow == 0 then
        mouse = { screenrow = vim.fn.screenrow(), screencol = vim.fn.screencol() }
    end

    -- Build action map and compute width
    local max_width = 0
    self._action_map = {}
    for i, item in ipairs(self._items) do
        if not item.separator then
            local label = (item.icon or '  ') .. ' ' .. item.text
            if #label > max_width then max_width = #label end
            self._action_map[i] = item.action
        end
    end

    local width = max_width + 4
    local height = #self._items
    local ew = Window.editor_width()
    local eh = Window.editor_height()
    local row = mouse.screenrow
    local col = mouse.screencol
    if row + height > eh then row = math.max(1, row - height) end
    if col + width > ew then col = math.max(1, col - width) end

    self._buf = Buffer.create({ listed = false, scratch = true })
    self._buf:set_option('bufhidden', 'wipe')
    self._buf:set_option('filetype', 'ide-menu')

    self._shadow = Shadow.for_float(row, col, width + 2, height + 2, 199)

    local float_config = {
        relative = 'editor',
        row = row,
        col = col,
        width = width,
        height = height,
        border = { '┌', '─', '┐', '│', '┘', '─', '└', '│' },
        style = 'minimal',
        zindex = 200,
        enter = true,
    }
    if self._title then
        float_config.title = { { ' ' .. self._title .. ' ', 'IDEMenuDropdownNormal' } }
        float_config.title_pos = 'center'
    end

    self._win = Window.open_float(self._buf, float_config)
    self._win:set_option('cursorline', false)
    self._win:set_option('winfixbuf', true)
    self._win:set_option('winhl', 'Normal:IDEMenuDropdownNormal,FloatBorder:IDEMenuDropdownBorder')
    self._win:set_option('winblend', 0)

    IDE.ui:hide_cursor('IDEMenuItemSelected')

    -- Find first actionable item
    local first = 1
    for i = 1, height do
        if self._action_map[i] then first = i; break end
    end

    -- Mount reactive component
    self._component = C.mount(ContextMenuView, {
        items = self._items,
        width = width,
        initial_selected = first,
        _state = {},
    }, self._buf, self._win)

    local menu = self
    local winid = self._win:id()

    local function state()
        return menu._component and menu._component.ctx.props._state or {}
    end

    local function submit()
        local s = state()
        local action = menu._action_map[s.selected]
        menu:close()
        if action then vim.schedule(action) end
    end

    local function move_to(target)
        if menu._action_map[target] then
            local s = state()
            if s.setSelected then s.setSelected(target) end
        end
    end

    local function move_next()
        local s = state()
        local cur = s.selected or 1
        for _ = 1, height do
            cur = cur % height + 1
            if menu._action_map[cur] then break end
        end
        move_to(cur)
    end

    local function move_prev()
        local s = state()
        local cur = s.selected or 1
        for _ = 1, height do
            cur = cur - 1
            if cur < 1 then cur = height end
            if menu._action_map[cur] then break end
        end
        move_to(cur)
    end

    local function map(key, fn) self._buf:bind_key('n', key, fn) end

    map('<CR>', submit)
    map('<LeftMouse>', function()
        local mpos = vim.fn.getmousepos()
        if mpos and mpos.winid == winid and mpos.line > 0 then
            if menu._action_map[mpos.line] then
                move_to(mpos.line)
                submit()
            end
        else
            menu:close()
        end
    end)
    map('j', move_next)
    map('<Down>', move_next)
    map('<Tab>', move_next)
    map('k', move_prev)
    map('<Up>', move_prev)
    map('<S-Tab>', move_prev)
    map('<Esc>', function() menu:close() end)
    map('q', function() menu:close() end)
    map('<RightMouse>', function() menu:close() end)
    map('<MouseMove>', function()
        local mpos = vim.fn.getmousepos()
        if mpos and mpos.winid == winid and mpos.line > 0 and menu._action_map[mpos.line] then
            move_to(mpos.line)
        end
    end)

    vim.api.nvim_create_autocmd({ 'WinLeave', 'BufLeave' }, {
        buffer = self._buf:id(),
        once = true,
        callback = function() menu:close() end,
    })
end

function ContextMenu:close()
    IDE.ui:restore_cursor()
    if self._component then
        C.unmount(self._component)
        self._component = nil
    end
    if self._shadow then self._shadow:close(); self._shadow = nil end
    if self._win and self._win:is_valid() then self._win:close(true) end
    if self._buf and self._buf:is_valid() then self._buf:close(true) end
    self._win = nil
    self._buf = nil
end

---@return string
function ContextMenu:__tostring()
    return string.format('ContextMenu(%d items)', #self._items)
end

return ContextMenu
