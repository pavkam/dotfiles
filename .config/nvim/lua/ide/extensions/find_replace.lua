-- Find/Replace Extension: TurboVision-style search and replace dialog.
-- Provides Ctrl+H for replace, incremental highlighting, and match navigation.

local Extension = require 'ide.Extension'
local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'
local Position = require 'ide.Position'

local FindReplace = Class('FindReplace', Extension)

function FindReplace:init()
    Extension.init(self, 'FindReplace')
    self._search_ns = nil
    self._last_search = ''
    self._last_replace = ''
end

function FindReplace:_get_ns()
    if not self._search_ns then
        self._search_ns = Buffer.create_namespace('ide_find_replace')
    end
    return self._search_ns
end

--- Clear all search highlights from a buffer.
---@param buf Buffer
function FindReplace:_clear_highlights(buf)
    if buf:is_valid() then
        buf:clear_extmarks(self:_get_ns())
    end
end

--- Highlight all matches of a pattern in a buffer.
---@param buf Buffer
---@param pattern string
---@return integer # match count
function FindReplace:_highlight_matches(buf, pattern)
    self:_clear_highlights(buf)
    if pattern == '' or not buf:is_valid() then return 0 end

    local ns = self:_get_ns()
    local count = 0
    local lines = buf:lines()

    for i, line in ipairs(lines) do
        local start = 1
        while true do
            local s, e = line:find(pattern, start, true)
            if not s then break end
            pcall(buf.set_extmark, buf, ns, i - 1, s - 1, {
                end_col = e,
                hl_group = 'IncSearch',
            })
            count = count + 1
            start = e + 1
            if start > #line then break end
        end
    end
    return count
end

--- Replace all occurrences in a buffer.
---@param buf Buffer
---@param search string
---@param replace string
---@return integer # replacement count
function FindReplace:_replace_all(buf, search, replace)
    if search == '' or not buf:is_valid() then return 0 end

    local lines = buf:lines()
    local count = 0
    local new_lines = {}

    for _, line in ipairs(lines) do
        local safe_replace = (replace:gsub('%%', '%%%%'))
        local new_line, n = line:gsub(vim.pesc(search), safe_replace)
        new_lines[#new_lines + 1] = new_line
        count = count + n
    end

    if count > 0 then
        buf:set_option('modifiable', true)
        buf:set_lines(0, -1, new_lines)
    end
    return count
end

--- Open the Find/Replace dialog.
function FindReplace:open()
    local Dialog = require 'ide.toolkit.Dialog'
    local InputField = require 'ide.toolkit.InputField'
    local Button = require 'ide.toolkit.Button'
    local Checkbox = require 'ide.toolkit.Checkbox'

    local buf = Buffer.current()
    if not buf:is_valid() then return end

    local ext = self
    local width = 50
    local dlg = Dialog({
        title = '&Find and Replace',
        width = width,
        height = 9,
        shadow = true,
        on_close = function()
            ext:_clear_highlights(buf)
        end,
    })

    -- Search input
    local search_label = { focusable = function() return false end }
    function search_label:render()
        return '  Search:', {{ group = 'IDEDialogNormal', col_start = 0, col_end = 9 }}
    end
    dlg:add_widget(search_label, 1, 1)

    local search_input = InputField({
        prompt = '',
        initial = ext._last_search,
        on_change = function(text)
            ext._last_search = text
            local count = ext:_highlight_matches(buf, text)
            -- Update match count display would go here
        end,
        on_submit = function(text)
            ext._last_search = text
            ext:_find_next(buf, text)
        end,
    })
    search_input:create_buffer()
    dlg:add_widget(search_input, 2, 2)

    -- Replace input
    local replace_label = { focusable = function() return false end }
    function replace_label:render()
        return '  Replace:', {{ group = 'IDEDialogNormal', col_start = 0, col_end = 10 }}
    end
    dlg:add_widget(replace_label, 3, 1)

    local replace_input = InputField({
        prompt = '',
        initial = ext._last_replace,
        on_change = function(text) ext._last_replace = text end,
    })
    replace_input:create_buffer()
    dlg:add_widget(replace_input, 4, 2)

    -- Buttons
    local btn_row = 6
    dlg:add_widget(Button({
        label = '&Find Next',
        style = 'primary',
        action = function()
            ext:_find_next(buf, ext._last_search)
        end,
    }), btn_row, 2)

    dlg:add_widget(Button({
        label = '&Replace All',
        action = function()
            local count = ext:_replace_all(buf, ext._last_search, ext._last_replace)
            ext:_clear_highlights(buf)
            dlg:close()
            if count > 0 then
                IDE.ui:info(count .. ' replacements made')
            else
                IDE.ui:info('No matches found')
            end
        end,
    }), btn_row, 16)

    dlg:add_widget(Button({
        label = '&Cancel',
        action = function()
            ext:_clear_highlights(buf)
            dlg:close()
        end,
    }), btn_row + 2, math.floor(width / 2) - 4)

    dlg:show()
end

--- Find the next occurrence and jump to it.
---@param buf Buffer
---@param pattern string
function FindReplace:_find_next(buf, pattern)
    if pattern == '' or not buf:is_valid() then return end

    local cursor = Window.current():cursor()
    local lines = buf:lines()

    -- Search from cursor position forward
    for i = cursor.row, #lines do
        local start_col = (i == cursor.row) and cursor.col + 1 or 1
        local s = lines[i]:find(pattern, start_col, true)
        if s then
            Window.current():set_cursor(Position(i, s))
            return
        end
    end
    -- Wrap around
    for i = 1, cursor.row do
        local s = lines[i]:find(pattern, 1, true)
        if s then
            Window.current():set_cursor(Position(i, s))
            IDE.ui:echo('Search wrapped', 'Comment')
            return
        end
    end
    IDE.ui:echo('Pattern not found: ' .. pattern, 'WarningMsg')
end

function FindReplace:on_register(ctx)
    local ext = self

    ctx:action('editor.findReplace', 'Find and Replace', function() ext:open() end)

    ctx:keymap('n', '<C-h>', 'editor.findReplace', { desc = 'Find and Replace' })
    ctx:command('IDEFindReplace', function() ext:open() end, { desc = 'Find and Replace dialog' })

end

---@return string
function FindReplace:__tostring()
    return 'FindReplace()'
end

return FindReplace
