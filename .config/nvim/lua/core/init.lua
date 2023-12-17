local utils = require 'core.utils'
local settings = require 'core.settings'

-- Load the core options
require 'core.options'

-- Disable some sequences
vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })
vim.keymap.set('n', '<BS>', '<Nop>', { silent = true })

-- Remap for dealing with word wrap
vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { desc = 'Move cursor up', expr = true })
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { desc = 'Move cursor down', expr = true })
vim.keymap.set('n', '<Up>', "v:count == 0 ? 'gk' : 'k'", { desc = 'Move cursor up', expr = true })
vim.keymap.set('n', '<Down>', "v:count == 0 ? 'gj' : 'j'", { desc = 'Move cursor down', expr = true })

-- Better normal mode navigation
vim.keymap.set({ 'n', 'x' }, 'gg', function()
    if vim.v.count > 0 then
        vim.cmd('normal! ' .. vim.v.count .. 'gg')
    else
        vim.cmd 'normal! gg0'
    end
end, { desc = 'Start of buffer' })

vim.keymap.set({ 'n', 'x' }, 'G', function()
    vim.cmd 'normal! G$'
end, { desc = 'End of buffer' })

-- move selection up/down
vim.keymap.set('v', 'J', ":m '>+1<CR>gv=gv", { desc = 'Move selection downward' })
vim.keymap.set('v', 'K', ":m '<-2<CR>gv=gv", { desc = 'Move selection upward' })

-- better indenting
vim.keymap.set('x', '<', '<gv', { desc = 'Indent selection' })
vim.keymap.set('x', '>', '>gv', { desc = 'Unindent selection' })

vim.keymap.set('x', '<Tab>', '>gv', { desc = 'Indent selection' })
vim.keymap.set('x', '<S-Tab>', '<gv', { desc = 'Unindent selection' })

-- Add undo break-points
vim.keymap.set('i', ',', ',<c-g>u')
vim.keymap.set('i', '.', '.<c-g>u')
vim.keymap.set('i', ';', ';<c-g>u')

-- Redo
vim.keymap.set('n', 'U', '<C-r>', { desc = 'Redo' })

-- Some editor mappings
vim.keymap.set('i', '<C-BS>', '<C-w>', { desc = 'Delete word' })

-- TODO: this misbehaves at time and doesn't introduce tab but jumps to something weird
vim.keymap.set('i', '<Tab>', function()
    local r, c = unpack(vim.api.nvim_win_get_cursor(0))
    if c and r then
        local line = vim.api.nvim_buf_get_lines(vim.fn.winbufnr(0), r - 1, r, true)[1]

        local before = string.sub(line, 1, c)
        local after = string.sub(line, c + 1, -1)

        if string.match(before, '^%s*$') ~= nil and string.match(after, '^%s*$') == nil then
            return '<C-t>'
        end
    end

    return '<Tab>'
end, { desc = 'Indent/Tab', expr = true })

vim.keymap.set('i', '<S-Tab>', '<C-d>', { desc = 'Unindent' })
vim.keymap.set('n', '<Tab>', '>>', { desc = 'Indent' })
vim.keymap.set('n', '<S-Tab>', '<<', { desc = 'Indent' })

-- Better page up/down
local function page_expr(dir)
    local jump = vim.api.nvim_win_get_height(0)
    if vim.v.count > 0 then
        jump = jump * vim.v.count
    end

    vim.cmd('normal! ' .. jump .. dir .. 'zz')
end

vim.keymap.set({ 'i', 'n' }, '<PageUp>', function()
    page_expr 'k'
end, { desc = 'Page up' })

vim.keymap.set({ 'x' }, '<S-PageUp>', function()
    page_expr 'k'
end, { desc = 'Page up' })

vim.keymap.set({ 'i', 'n' }, '<PageDown>', function()
    page_expr 'j'
end, { desc = 'Page down' })

vim.keymap.set({ 'x' }, '<S-PageDown>', function()
    page_expr 'j'
end, { desc = 'Page down' })

-- Disable the annoying yank on chnage
vim.keymap.set({ 'n', 'x' }, 'c', [["_c]], { desc = 'Change' })
vim.keymap.set({ 'n', 'x' }, 'C', [["_C]], { desc = 'Change' })
vim.keymap.set('x', 'p', 'P', { desc = 'Paste' })
vim.keymap.set('x', 'P', 'p', { desc = 'Yank & paste' })
vim.keymap.set('n', 'x', [["_x]], { desc = 'Delete character' })
vim.keymap.set('n', '<Del>', [["_x]], { desc = 'Delete character' })
vim.keymap.set('x', '<BS>', 'd', { desc = 'Delete selection' })

-- window navigation
if not utils.has_plugin 'nvim-tmux-navigation' then
    vim.keymap.set('n', '<M-Tab>', '<C-W>w', { desc = 'Switch window' })
    vim.keymap.set('n', '<M-Left>', '<cmd>wincmd h<cr>', { desc = 'Go to left window' })
    vim.keymap.set('n', '<M-Right>', '<cmd>wincmd l<cr>', { desc = 'Go to right window' })
    vim.keymap.set('n', '<M-Down>', '<cmd>wincmd j<cr>', { desc = 'Go to window below' })
    vim.keymap.set('n', '<M-Up>', '<cmd>wincmd k<cr>', { desc = 'Go to window above' })
end

vim.keymap.set('n', '\\', '<C-W>s', { desc = 'Split window below' })
vim.keymap.set('n', '|', '<C-W>v', { desc = 'Split window right' })

--- Inserts a new line and pastes
---@param op "o"|"O" # the operation to perform
local function ins_paste(op)
    local count = vim.v.count

    vim.cmd('normal! ' .. op)
    vim.cmd 'stopinsert'
    if count > 0 then
        vim.cmd('normal! ' .. count .. 'p')
    else
        vim.cmd 'normal! p'
    end
end

vim.keymap.set('n', 'go', function()
    ins_paste 'o'
end, { desc = 'Paste below' })

vim.keymap.set('n', 'gO', function()
    ins_paste 'O'
end, { desc = 'Paste below' })

-- Better jump list navigation
vim.keymap.set('n', ']]', '<C-i>', { desc = 'Next location' })
vim.keymap.set('n', '[[', '<C-o>', { desc = 'Previous location' })

-- terminal mappings
vim.keymap.set('t', '<esc><esc>', '<c-\\><c-n>', { desc = 'Enter normal mode' })

-- buffer management
vim.keymap.set('n', '<leader><leader>', function()
    ---@diagnostic disable-next-line: param-type-mismatch
    pcall(vim.cmd, 'e #')
end, { desc = 'Switch buffer', silent = true })
vim.keymap.set('n', '<leader>bw', '<cmd>w<cr>', { desc = 'Save buffer' })

vim.keymap.set('n', '[b', '<cmd>bprevious<cr>', { desc = 'Previous buffer' })
vim.keymap.set('n', ']b', '<cmd>bnext<cr>', { desc = 'Next buffer' })

-- tabs
vim.keymap.set('n', ']t', '<cmd>tabnext<cr>', { desc = 'Next tab' })
vim.keymap.set('n', '[t', '<cmd>tabprevious<cr>', { desc = 'Previous tab' })

-- check if the file has been changed outside of neovim
utils.on_event({ 'FocusGained', 'TermClose', 'TermLeave' }, function()
    vim.cmd.checktime()
end)

-- show cursor only in active window
utils.on_event({ 'InsertLeave', 'WinEnter' }, function(evt)
    if vim.bo[evt.buf].buftype == '' then
        vim.opt_local.cursorline = true
    end
end)

utils.on_event({ 'InsertEnter', 'WinLeave' }, function()
    vim.opt_local.cursorline = false
end)

-- highlight on yank
utils.on_event('TextYankPost', function()
    vim.highlight.on_yank()
end)

-- resize splits if window got resized
utils.on_event('VimResized', function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd 'tabdo wincmd ='
    vim.cmd('tabnext ' .. current_tab)
end)

-- Exit insert mode when switching buffers
utils.on_event('BufEnter', function(evt)
    local ignored_fts = { 'TelescopePrompt' }

    if vim.fn.mode() == 'i' and vim.tbl_contains(ignored_fts, vim.api.nvim_buf_get_option(evt.buf, 'filetype')) then
        vim.cmd 'stopinsert'
    end
end)

-- pin special buffers into their windows and prevent accidental
-- replacement of them
local just_removed = {}

utils.on_event('BufWinLeave', function(evt)
    local upd = utils.is_special_buffer(evt.buf) and evt.buf --[[@as integer]]
        or nil

    for _, win in ipairs(vim.fn.win_findbuf(evt.buf)) do
        just_removed[win] = upd
    end
end)

utils.on_event({ 'BufWinEnter', 'BufEnter' }, function(evt)
    local win = vim.api.nvim_get_current_win()
    local new_buffer = evt.buf
    local old_buffer = just_removed[win]

    if old_buffer and vim.api.nvim_buf_is_valid(old_buffer) and not utils.is_special_buffer(new_buffer) then
        just_removed[win] = nil
        vim.api.nvim_set_current_buf(old_buffer)
    end
end)

-- mkview and loadview for real files
utils.on_event({ 'BufWinLeave', 'BufWritePost', 'WinLeave' }, function(evt)
    if settings.get('view_activated', { buffer = evt.buf }) then
        vim.cmd.mkview { mods = { emsg_silent = true } }
    end
end)

utils.on_event('BufWinEnter', function(evt)
    if not settings.get('view_activated', { buffer = evt.buf }) then
        local filetype = vim.api.nvim_get_option_value('filetype', { buf = evt.buf })
        local buftype = vim.api.nvim_get_option_value('buftype', { buf = evt.buf })
        local ignore_filetypes = { 'gitcommit', 'gitrebase', 'svg', 'hgcommit' }

        if buftype == '' and filetype and filetype ~= '' and not vim.tbl_contains(ignore_filetypes, filetype) then
            settings.set('view_activated', true, { buffer = evt.buf })
            vim.cmd.loadview { mods = { emsg_silent = true } }
        end
    end
end)

-- Auto create dir when saving a file, in case some intermediate directory does not exist
utils.on_event('BufWritePre', function(evt)
    if evt.match:match '^%w%w+://' then
        return
    end

    local file = vim.loop.fs_realpath(evt.match) or evt.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ':p:h'), 'p')
end)
