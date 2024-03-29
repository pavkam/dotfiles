local utils = require 'core.utils'
local settings = require 'core.settings'
local syntax = require 'editor.syntax'

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

-- Disable the annoying yank on change
vim.keymap.set({ 'n', 'x' }, 'c', [["_c]], { desc = 'Change' })
vim.keymap.set({ 'n', 'x' }, 'C', [["_C]], { desc = 'Change' })
vim.keymap.set('x', 'p', 'P', { desc = 'Paste' })
vim.keymap.set('x', 'P', 'p', { desc = 'Yank & paste' })
vim.keymap.set('n', 'x', [["_x]], { desc = 'Delete character' })
vim.keymap.set('n', '<Del>', [["_x]], { desc = 'Delete character' })
vim.keymap.set('x', '<BS>', 'd', { desc = 'Delete selection' })

vim.keymap.set('n', 'dd', function()
    if vim.api.nvim_get_current_line():match '^%s*$' then
        return '"_dd'
    else
        return 'dd'
    end
end, { desc = 'Delete line', expr = true })

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

vim.keymap.set('n', 'gp', function()
    ins_paste 'o'
end, { desc = 'Paste below' })

vim.keymap.set('n', 'gP', function()
    ins_paste 'O'
end, { desc = 'Paste above' })

-- search
vim.keymap.set({ 'i', 'n' }, '<esc>', '<cmd>nohlsearch<cr><esc>', { desc = 'Escape and clear highlight' })
vim.keymap.set('n', 'n', "'Nn'[v:searchforward].'zv'", { expr = true, desc = 'Next search result' })
vim.keymap.set({ 'x', 'o' }, 'n', "'Nn'[v:searchforward]", { expr = true, desc = 'Next search result' })
vim.keymap.set('n', 'N', "'nN'[v:searchforward].'zv'", { expr = true, desc = 'Previous search result' })
vim.keymap.set({ 'x', 'o' }, 'N', "'nN'[v:searchforward]", { expr = true, desc = 'Previous search result' })
vim.keymap.set('x', '<C-r>', function()
    local selected_text = utils.get_selected_text()
    local command = ':<C-u>%s/\\<' .. selected_text .. '\\>/' .. selected_text .. '/gI<Left><Left><Left>'
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(command, true, false, true), 'n', false)
end, { desc = 'Replace selection' })
vim.keymap.set('n', '<C-r>', [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], { desc = 'Replace word under cursor' })

-- special keys
vim.keymap.set('n', '<M-s>', '<cmd>w<cr>', { desc = 'Save buffer' })
vim.keymap.set('n', '<M-x>', 'dd', { desc = 'Delete line' })
vim.keymap.set('x', '<M-x>', 'd', { desc = 'Delete selection' })
vim.keymap.set('n', '<M-a>', 'ggVG', { desc = 'Select all', remap = true })

vim.keymap.set('x', '.', ':norm .<CR>', { desc = 'Repeat edit' })
vim.keymap.set('x', '@', ':norm @q<CR>', { desc = 'Repeat macro' })

vim.keymap.set('i', '<LeftMouse>', '<Esc><LeftMouse>', { desc = 'Exit insert mode and left-click' })
vim.keymap.set('i', '<RightMouse>', '<Esc><RightMouse>', { desc = 'Exit insert mode and right-click' })

-- better search
vim.on_key(function(char)
    if vim.fn.mode() == 'n' then
        local new_hlsearch = vim.tbl_contains({ '<CR>', 'n', 'N', '*', '#', '?', '/' }, vim.fn.keytrans(char))
        if vim.opt.hlsearch:get() ~= new_hlsearch then
            vim.opt.hlsearch = new_hlsearch
        end
    end
end, vim.api.nvim_create_namespace 'auto_hlsearch')

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

if not utils.has_plugin 'auto-session' then
    -- Turn on view generation and loading only if session management is not enabled
    utils.on_event({ 'BufWinLeave', 'BufWritePost', 'WinLeave' }, function(evt)
        if settings.get('view_activated', { buffer = evt.buf, scope = 'instance' }) then
            vim.cmd.mkview { mods = { emsg_silent = true } }
        end
    end)

    utils.on_event('BufWinEnter', function(evt)
        if not settings.get('view_activated', { buffer = evt.buf, scope = 'instance' }) then
            local filetype = vim.api.nvim_get_option_value('filetype', { buf = evt.buf })
            local buftype = vim.api.nvim_get_option_value('buftype', { buf = evt.buf })
            local ignore_filetypes = { 'gitcommit', 'gitrebase', 'svg', 'hgcommit' }

            if buftype == '' and filetype and filetype ~= '' and not vim.tbl_contains(ignore_filetypes, filetype) then
                settings.set('view_activated', true, { buffer = evt.buf, scope = 'instance' })
                vim.cmd.loadview { mods = { emsg_silent = true } }
            end
        end
    end)
end

-- disable swap/undo files for certain filetypes
utils.on_event('BufWritePre', function(evt)
    vim.opt_local.undofile = false
    if evt.file == 'COMMIT_EDITMSG' or evt.file == 'MERGE_MSG' then
        vim.opt_local.swapfile = false
    end
end, { '/tmp/*', '*.tmp', '*.bak', 'COMMIT_EDITMSG', 'MERGE_MSG' })

-- disable swap/undo/backup files in temp directories or shm
utils.on_event({ 'BufNewFile', 'BufReadPre' }, function()
    vim.opt_local.undofile = false
    vim.opt_local.swapfile = false
    vim.opt_global.backup = false
    vim.opt_global.writebackup = false
end, {
    '/tmp/*',
    '$TMPDIR/*',
    '$TMP/*',
    '$TEMP/*',
    '*/shm/*',
    '/private/var/*',
})

-- forget files that have been deleted
utils.on_event({ 'BufDelete', 'BufEnter' }, function(evt)
    if utils.is_special_buffer(evt.buf) then
        return
    end

    local file = vim.api.nvim_buf_get_name(evt.buf)
    if not file or file == '' or utils.file_exists(file) then
        return
    end

    require('ui.marks').forget(file)
    require('core.old_files').forget(file)
    require('ui.qf').forget(file)
end)
