-- Mouse: context-aware right-click menu system.
-- Uses Buffer.add_context_provider() as the slot for context actions.
-- Components (LSP, Git, Diagnostics) register their own providers.

local EventEmitter = require 'ide.EventEmitter'
local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'
local Position = require 'ide.Position'

local Mouse = Class('Mouse')
Class.include(Mouse, EventEmitter)

function Mouse:init()
    self._active_menu = nil
end

--- Get the current mouse position.
---@return { screenrow: integer, screencol: integer, winid: integer, line: integer, column: integer }|nil
function Mouse:position()
    local pos = vim.fn.getmousepos()
    if not pos or pos.screenrow == 0 then return nil end
    return {
        screenrow = pos.screenrow,
        screencol = pos.screencol,
        winid = pos.winid,
        line = pos.line,
        column = pos.column,
    }
end

--- Check if mouse is over the menu bar (screenrow == 1).
---@return boolean
function Mouse:is_on_menubar()
    local pos = self:position()
    return pos ~= nil and pos.screenrow == 1
end

--- Show the right-click context menu.
function Mouse:show_context_menu()
    if self._active_menu then
        self._active_menu:close()
        self._active_menu = nil
    end

    local mouse = vim.fn.getmousepos()
    if mouse and mouse.winid and mouse.winid > 0 then
        local win = Window.get(mouse.winid)
        if not win then return end
        win:focus()
        if mouse.line > 0 then
            win:set_cursor(Position(mouse.line, math.max(1, mouse.column)))
        end
    end

    local buf = Buffer.current()
    local row = Window.current():cursor().row
    local action_groups = buf:context_actions(row)

    local items = {}
    for i, group in ipairs(action_groups) do
        if i > 1 then
            items[#items + 1] = { separator = true }
        end
        for _, item in ipairs(group.items) do
            items[#items + 1] = item
        end
    end

    if #items == 0 then return end

    local ContextMenu = require 'ide.toolkit.ContextMenu'
    self._active_menu = ContextMenu(items)
    self._active_menu:show()

    self:emit('context_menu', buf, row)
end

--- Wire up the right-click mapping.
function Mouse:_wire_events()
    IDE.keys:map({ 'n', 'v' }, '<RightMouse>', function()
        self:show_context_menu()
    end, { desc = 'Context menu', silent = true })
end

---@return string
function Mouse:__tostring()
    return 'Mouse()'
end

return Mouse
