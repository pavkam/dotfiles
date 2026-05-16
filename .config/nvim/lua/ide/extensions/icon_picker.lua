-- Icon Picker Extension: search and insert nerd font icons.
-- Uses the full nerd fonts database (10,000+ icons) from nerd_icons_db.lua.
-- Provides fuzzy search via telescope for fast icon finding.

local Extension = require 'ide.Extension'
local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'
local Position = require 'ide.Position'

local IconPicker = Class('IconPicker', Extension)

function IconPicker:init()
    Extension.init(self, 'IconPicker')
    self._db = nil
end

function IconPicker:_load_db()
    if not self._db then
        self._db = require 'ide.extensions.nerd_icons_db'
    end
    return self._db
end

--- Insert an icon at the current cursor position.
---@param icon string
local function insert_icon(icon)
    local win = Window.current()
    local cursor = win:cursor()
    Buffer.current():set_text(cursor.row - 1, cursor.col - 1, cursor.row - 1, cursor.col - 1, { icon })
    win:set_cursor(Position(cursor.row, cursor.col + #icon))
end

function IconPicker:pick()
    local buf = require('ide.Buffer').current()
    if not buf:is_normal() or not buf:is_modifiable() then
        self:copy()
        return
    end
    local db = self:_load_db()
    local SelectPicker = require 'ide.toolkit.SelectPicker'

    local items = {}
    for _, entry in ipairs(db) do
        items[#items + 1] = {
            text = entry.name,
            icon = entry.char,
            value = entry.char,
        }
    end

    SelectPicker({
        title = 'Nerd Font Icons (' .. #db .. ')',
        items = items,
        on_select = function(item)
            insert_icon(item.value)
        end,
    }):show()
end

function IconPicker:copy()
    local db = self:_load_db()
    IDE.ui:select(
        vim.tbl_map(function(e) return e.char .. '  ' .. e.name end, db),
        { prompt = 'Copy icon:' },
        function(choice)
            if choice then
                local icon = choice:sub(1, choice:find(' ') - 1)
                IDE.ui:copy_to_clipboard(icon)
                IDE.ui:info('Copied: ' .. icon)
            end
        end
    )
end

function IconPicker:on_register(ctx)
    local self_ref = self
    ctx:command('IDEIcons', function() self_ref:pick() end, { desc = 'Pick and insert a nerd font icon' })
    ctx:keymap('n', '<leader>i', function() self_ref:pick() end, { desc = 'Pick icon' })
end

return IconPicker
