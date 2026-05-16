-- Jump extension: quick navigation via labeled matches.
-- Replaces flash.nvim with a simpler, OOP-based implementation.
--
-- Features:
--   - Multi-window jump: labels appear across ALL visible windows
--   - Incremental narrowing: labels update as you type more characters
--   - Operator-pending mode: works with d, c, y, etc.

local Extension = require 'ide.Extension'
local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'
local Position = require 'ide.Position'

local Jump = Class('Jump', Extension)

function Jump:init()
    Extension.init(self, 'Jump')
    self._ns = Buffer.create_namespace('ide_jump')
    self._labels = 'asdfghjklqwertyuiopzxcvbnm'
end

--- Collect all visible, non-floating windows sorted by proximity to current.
---@return Window[]
function Jump:_visible_windows()
    local current = Window.current()
    local current_id = current:id()
    local wins = {}
    for _, win in ipairs(Window.list()) do
        if win:is_valid() and not win:is_floating() then
            wins[#wins + 1] = win
        end
    end
    -- Sort: current window first, then by window id for stability
    table.sort(wins, function(a, b)
        local a_current = a:id() == current_id
        local b_current = b:id() == current_id
        if a_current ~= b_current then return a_current end
        return a:id() < b:id()
    end)
    return wins
end

--- Find matches across all visible windows.
---@param pattern string
---@return { row: integer, col: integer, win: Window, buf: Buffer }[]
function Jump:_find_matches_multi(pattern)
    local matches = {}
    local current_win = Window.current()
    local cursor = current_win:cursor()

    for _, win in ipairs(self:_visible_windows()) do
        local buf = win:buffer()
        local top, bot = win:visible_range()
        local is_current = win:id() == current_win:id()

        for lnum = top, bot do
            local line = buf:line(lnum)
            local col = 0
            while col < #line do
                local s, e = line:find(pattern, col + 1, true)
                if not s then break end
                -- Skip cursor position in the current window
                if not (is_current and lnum == cursor.row and s == cursor.col) then
                    matches[#matches + 1] = { row = lnum, col = s - 1, win = win, buf = buf }
                end
                col = e
            end
        end
    end
    return matches
end

--- Show labels on matches and dim all visible windows. Returns selected target.
---@param matches { row: integer, col: integer, win: Window, buf: Buffer }[]
---@return { row: integer, col: integer, win: Window }|nil
function Jump:_show_labels(matches)
    local labeled = {}
    local dimmed_bufs = {}

    for i, m in ipairs(matches) do
        if i > #self._labels then break end
        local label = self._labels:sub(i, i)
        labeled[#labeled + 1] = { match = m, label = label }

        pcall(function()
            m.buf:set_extmark(self._ns, m.row - 1, m.col, {
                virt_text = { { label, 'FlashLabel' } },
                virt_text_pos = 'overlay',
                priority = 9999,
                hl_mode = 'combine',
            })
        end)
    end

    -- Dim all visible windows
    for _, win in ipairs(self:_visible_windows()) do
        local buf = win:buffer()
        local buf_id = buf:id()
        if not dimmed_bufs[buf_id] then
            dimmed_bufs[buf_id] = buf
            local top, bot = win:visible_range()
            for row = top - 1, bot - 1 do
                pcall(function()
                    buf:set_extmark(self._ns, row, 0, {
                        line_hl_group = 'FlashDim',
                        priority = 1,
                    })
                end)
            end
        end
    end

    IDE.ui:refresh()

    local char = IDE.ui:getchar()

    -- Clear extmarks from all affected buffers
    for _, buf in pairs(dimmed_bufs) do
        if buf:is_valid() then
            buf:clear_extmarks(self._ns)
        end
    end

    if not char then return nil end

    for _, l in ipairs(labeled) do
        if l.label == char then
            return l.match
        end
    end
    return nil
end

--- Clear all jump extmarks from all visible windows.
function Jump:_clear_all()
    local cleared = {}
    for _, win in ipairs(self:_visible_windows()) do
        local buf = win:buffer()
        local buf_id = buf:id()
        if not cleared[buf_id] and buf:is_valid() then
            cleared[buf_id] = true
            buf:clear_extmarks(self._ns)
        end
    end
end

--- Show labels for matches and refresh them without waiting for a keypress.
--- Returns the labeled entries so the caller can resolve a later keypress.
---@param matches { row: integer, col: integer, win: Window, buf: Buffer }[]
---@return { match: { row: integer, col: integer, win: Window, buf: Buffer }, label: string }[]
function Jump:_render_labels(matches)
    local labeled = {}
    local dimmed_bufs = {}

    for i, m in ipairs(matches) do
        if i > #self._labels then break end
        local label = self._labels:sub(i, i)
        labeled[#labeled + 1] = { match = m, label = label }

        pcall(function()
            m.buf:set_extmark(self._ns, m.row - 1, m.col, {
                virt_text = { { label, 'FlashLabel' } },
                virt_text_pos = 'overlay',
                priority = 9999,
                hl_mode = 'combine',
            })
        end)
    end

    -- Dim all visible windows
    for _, win in ipairs(self:_visible_windows()) do
        local buf = win:buffer()
        local buf_id = buf:id()
        if not dimmed_bufs[buf_id] then
            dimmed_bufs[buf_id] = buf
            local top, bot = win:visible_range()
            for row = top - 1, bot - 1 do
                pcall(function()
                    buf:set_extmark(self._ns, row, 0, {
                        line_hl_group = 'FlashDim',
                        priority = 1,
                    })
                end)
            end
        end
    end

    IDE.ui:refresh()
    return labeled
end

--- Navigate to a target, focusing its window if needed.
---@param target { row: integer, col: integer, win: Window }
function Jump:_goto_target(target)
    local current_win = Window.current()
    if target.win:id() ~= current_win:id() then
        target.win:focus()
    end
    target.win:set_cursor(Position(target.row, target.col + 1))
end

--- Main jump entry point.
--- Supports incremental narrowing: each typed character narrows the match set.
--- Works across all visible windows.
function Jump:jump()
    local pattern = ''

    -- First character
    IDE.ui:echo('Jump: ', 'FlashPrompt')
    local c1 = IDE.ui:getchar()
    if not c1 then return end
    pattern = c1

    local matches = self:_find_matches_multi(pattern)
    if #matches == 0 then
        IDE.ui:echo('No matches', 'WarningMsg')
        return
    end

    -- Single match: jump directly
    if #matches == 1 then
        self:_goto_target(matches[1])
        return
    end

    -- Incremental narrowing loop:
    -- If too many matches for labels, keep asking for characters to narrow.
    -- Once matches fit in label count, show labels and pick.
    while #matches > #self._labels do
        -- Show current labels on top matches as a preview
        self:_clear_all()
        local labeled = self:_render_labels(matches)

        IDE.ui:echo('Jump: ' .. pattern, 'FlashPrompt')
        local cn = IDE.ui:getchar()
        self:_clear_all()

        if not cn then return end

        -- Check if the user pressed a label key that matches a visible label
        for _, l in ipairs(labeled) do
            if l.label == cn then
                self:_goto_target(l.match)
                return
            end
        end

        -- Otherwise, treat as narrowing character
        pattern = pattern .. cn
        matches = self:_find_matches_multi(pattern)

        if #matches == 0 then
            IDE.ui:echo('No matches', 'WarningMsg')
            return
        end

        if #matches == 1 then
            self:_goto_target(matches[1])
            return
        end
    end

    -- Matches fit in labels: show labels and wait for selection
    self:_clear_all()
    local target = self:_show_labels(matches)
    if target then
        self:_goto_target(target)
    end
end

function Jump:treesitter_select()
    local node = IDE.treesitter:node_at_cursor()
    if not node then
        IDE.ui:warn('No treesitter node at cursor')
        return
    end

    local sr, sc, er, ec = node:range()
    Window.current():select_range(
        Position(sr + 1, sc + 1),
        Position(er + 1, math.max(1, ec))
    )
end

function Jump:on_register(ctx)
    local ext = self

    IDE.ui:highlight('FlashLabel'):fg('#ff007c'):bg('#1a1b26'):bold():nocombine():as_default():define()
    IDE.ui:highlight('FlashDim'):fg('#545c7e'):as_default():define()
    IDE.ui:highlight('FlashPrompt'):fg('#7dcfff'):bold():as_default():define()

    ctx:keymap({ 'n', 'x', 'o' }, '<M-/>', function()
        ext:jump()
    end, { desc = 'Jump to match' })

    ctx:keymap({ 'n', 'o', 'x' }, '<C-_>', function()
        ext:treesitter_select()
    end, { desc = 'Treesitter select' })

    ctx:notify('Jump navigation active')
end

return Jump
