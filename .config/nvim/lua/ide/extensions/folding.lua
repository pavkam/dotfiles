-- Folding extension: enhanced code folding.
-- Replaces nvim-ufo with native treesitter folding + custom foldtext + peek.

local Extension = require 'ide.Extension'
local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'

local Folding = Class('Folding', Extension)

function Folding:init()
    Extension.init(self, 'Folding')
    self._peek_ns = Buffer.create_namespace('ide_fold_peek')
    self._peek_win = nil
end

-- NOTE: foldtext() is a Neovim callback — vim.v.foldstart/foldend are the
-- interface contract and cannot be abstracted.
---@return string
function Folding.foldtext()
    local foldstart = vim.v.foldstart
    local foldend = vim.v.foldend
    local line = Buffer.current():line(foldstart)
    local trimmed = line:gsub('^%s+', '')
    local indent = line:match('^(%s*)')
    local count = foldend - foldstart + 1
    return indent .. trimmed .. '  ⋯ ' .. count .. ' lines'
end

function Folding:open_all()
    Window.current():exec_normal('zR')
end

function Folding:close_all()
    Window.current():exec_normal('zM')
end

function Folding:open_level()
    local win = Window.current()
    win:set_option('foldlevel', win:option('foldlevel') + 1)
end

function Folding:close_level()
    local win = Window.current()
    win:set_option('foldlevel', math.max(0, win:option('foldlevel') - 1))
end

function Folding:peek()
    if self._peek_win and Window.is_valid(self._peek_win) then
        pcall(vim.api.nvim_win_close, self._peek_win, true)
        self._peek_win = nil
        return
    end

    local win = Window.current()
    local cursor_line = win:cursor().row
    local foldstart, foldend = win:fold_range(cursor_line)

    if not foldstart then
        IDE.ui:info('No fold under cursor')
        return
    end

    local source = Buffer.current()
    local lines = source:lines(foldstart - 1, foldend)
    local max_width = 0
    for _, l in ipairs(lines) do
        max_width = math.max(max_width, #l)
    end

    local preview = Buffer.create({ listed = false, scratch = true })
    preview:set_lines(0, -1, lines)
    preview:set_option('modifiable', false)
    preview:set_option('bufhidden', 'wipe')
    preview:set_option('filetype', source:filetype())

    local width = math.min(max_width + 2, math.floor(Window.editor_width() * 0.8))
    local height = math.min(#lines, math.floor(Window.editor_height() * 0.5))

    local peek_win = Window.open_float(preview, {
        relative = 'cursor',
        row = 1,
        col = 0,
        width = width,
        height = height,
        style = 'minimal',
        border = 'rounded',
        zindex = 100,
    })
    self._peek_win = peek_win:id()

    peek_win:set_option('cursorline', false)
    peek_win:set_option('number', true)
    peek_win:set_option('relativenumber', false)

    local self_ref = self
    self._ctx:hook({ 'CursorMoved', 'BufLeave', 'WinLeave' }, function()
        if self_ref._peek_win and Window.is_valid(self_ref._peek_win) then
            pcall(vim.api.nvim_win_close, self_ref._peek_win, true)
            self_ref._peek_win = nil
        end
    end, { once = true })
end

function Folding:on_register(ctx)
    local ext = self

    ctx:hook('FileType', function(evt)
        if not Buffer.is_valid(evt.buf) or Buffer.get(evt.buf):option('buftype') ~= '' then return end

        local win = Window.current()
        win:set_option('foldmethod', 'expr')
        win:set_option('foldexpr', 'v:lua.vim.treesitter.foldexpr()')
        win:set_option('foldtext', 'v:lua.require("ide.extensions.folding").foldtext()')
        win:set_option('foldlevel', 99)
        win:set_option('foldenable', true)
        win:set_option('foldcolumn', '1')
    end, { desc = 'Set folding options' })

    ctx:keymap('n', 'zR', function() ext:open_all() end, { desc = 'Open all folds' })
    ctx:keymap('n', 'zM', function() ext:close_all() end, { desc = 'Close all folds' })
    ctx:keymap('n', 'zr', function() ext:open_level() end, { desc = 'Fold less' })
    ctx:keymap('n', 'zm', function() ext:close_level() end, { desc = 'Fold more' })
    ctx:keymap('n', 'zp', function() ext:peek() end, { desc = 'Peek fold' })

    ctx:notify('Enhanced folding active')
end

return Folding
