-- Indent guide extension.
-- Replaces indent-blankline.nvim with a pure OOP implementation.

local Extension = require 'ide.Extension'
local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'
local Timer = require 'ide.Timer'

local IndentGuides = Class('IndentGuides', Extension)

function IndentGuides:init()
    Extension.init(self, 'IndentGuides')
    self._ns = Buffer.create_namespace('ide_indent_guides')
    self._char = '│'
    self._scope_char = '│'
    self._exclude_ft = {
        'help', 'ide-filetree', 'lazy', 'mason', 'notify',
        'toggleterm', 'lazyterm', 'TelescopePrompt', 'dashboard',
        'alpha', '', 'checkhealth', 'man', 'gitcommit', 'gitrebase',
        'ide-panel',
    }
    self._exclude_bt = { 'terminal', 'nofile', 'prompt' }
end

---@param line string
---@param tabstop integer
---@return integer
function IndentGuides.get_indent_level(line, tabstop)
    local indent = 0
    for i = 1, #line do
        local c = line:sub(i, i)
        if c == ' ' then
            indent = indent + 1
        elseif c == '\t' then
            indent = indent + tabstop - (indent % tabstop)
        else
            break
        end
    end
    return indent
end

---@param bufnr integer
---@return boolean
function IndentGuides:_should_render(bufnr)
    if not Buffer.is_valid(bufnr) then return false end
    local buf = Buffer.get(bufnr)
    if not buf:is_normal() then return false end
    local ft = buf:filetype()
    if vim.tbl_contains(self._exclude_ft, ft) then return false end
    return true
end

---@param win Window
function IndentGuides:_render_window(win)
    if not win:is_valid() or win:is_floating() then return end

    local buf = win:buffer()
    if not self:_should_render(buf:id()) then return end

    local top, bot = win:visible_range()
    local lines = buf:lines(top - 1, bot)
    local sw = buf:option('shiftwidth')
    if sw == 0 then sw = buf:option('tabstop') end
    if sw == 0 then sw = 4 end
    local tabstop = buf:option('tabstop')

    buf:clear_extmarks(self._ns, top - 1, bot)

    local cursor_row = win:cursor().row - 1
    local scope_start, scope_end = IDE.treesitter:scope_range(buf:id(), cursor_row)

    for i, line in ipairs(lines) do
        local row = top - 1 + i - 1
        local indent = IndentGuides.get_indent_level(line, tabstop)
        local is_blank = line:match('^%s*$') ~= nil

        if is_blank then
            local prev_indent, next_indent = 0, 0
            for j = i - 1, 1, -1 do
                if not lines[j]:match('^%s*$') then
                    prev_indent = IndentGuides.get_indent_level(lines[j], tabstop)
                    break
                end
            end
            for j = i + 1, #lines do
                if not lines[j]:match('^%s*$') then
                    next_indent = IndentGuides.get_indent_level(lines[j], tabstop)
                    break
                end
            end
            indent = math.min(prev_indent, next_indent)
        end

        for level = sw, indent - 1, sw do
            local in_scope = scope_start and scope_end
                and row >= scope_start and row <= scope_end

            pcall(function()
                buf:set_extmark(self._ns, row, 0, {
                    virt_text = { { in_scope and self._scope_char or self._char, in_scope and 'IblScope' or 'IblIndent' } },
                    virt_text_pos = 'overlay',
                    virt_text_win_col = level,
                    priority = in_scope and 1025 or 1,
                    hl_mode = 'combine',
                })
            end)
        end
    end
end

function IndentGuides:on_register(ctx)
    local ext = self

    IDE.theme:define('IblIndent', { fg = '#3b4261', nocombine = true, default = true })
    IDE.theme:define('IblScope', { fg = '#737aa2', nocombine = true, default = true })

    local render = Timer.debounce(50, function()
        for win in IDE.windows:iter() do
            pcall(ext._render_window, ext, win)
        end
    end)

    ctx:hook({ 'BufEnter', 'BufWritePost', 'CursorMoved', 'CursorMovedI', 'WinScrolled', 'TextChanged', 'TextChangedI' }, function()
        render()
    end, { desc = 'Render indent guides' })

    ctx:notify('Indent guides active')
end

return IndentGuides
