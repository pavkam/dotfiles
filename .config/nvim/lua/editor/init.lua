local buffers = require 'core.buffers'
local events = require 'core.events'
local keys = require 'core.keys'
local settings = require 'core.settings'
local syntax = require 'editor.syntax'

require 'editor.spelling'
require 'editor.comments'

-- Remap for dealing with word wrap
keys.map('n', 'k', "v:count == 0 ? 'gk' : 'k'", { desc = 'Move cursor up', expr = true })
keys.map('n', 'j', "v:count == 0 ? 'gj' : 'j'", { desc = 'Move cursor down', expr = true })
keys.map('n', '<Up>', "v:count == 0 ? 'gk' : 'k'", { desc = 'Move cursor up', expr = true })
keys.map('n', '<Down>', "v:count == 0 ? 'gj' : 'j'", { desc = 'Move cursor down', expr = true })

-- Better normal mode navigation
keys.map({ 'n', 'x' }, 'gg', function()
    if vim.v.count > 0 then
        vim.cmd('normal! ' .. vim.v.count .. 'gg')
    else
        vim.cmd 'normal! gg0'
    end
end, { desc = 'Start of buffer' })

keys.map({ 'n', 'x' }, 'G', function()
    vim.cmd 'normal! G$'
end, { desc = 'End of buffer' })

-- move selection up/down
keys.map('v', 'J', ":m '>+1<CR>gv=gv", { desc = 'Move selection downward' })
keys.map('v', 'K', ":m '<-2<CR>gv=gv", { desc = 'Move selection upward' })

-- better indenting
keys.map('x', '<', '<gv', { desc = 'Indent selection' })
keys.map('x', '>', '>gv', { desc = 'Unindent selection' })

keys.map('x', '<Tab>', '>gv', { desc = 'Indent selection' })
keys.map('x', '<S-Tab>', '<gv', { desc = 'Unindent selection' })

-- Add undo break-points
for _, key in ipairs { '.', ',', '!', '?', ';', ':', '"', "'" } do
    keys.map(
        'i',
        key,
        string.format('%s<c-g>u', key),
        { desc = string.format('Insert %s and an undo break-point', key) }
    )
end

-- Redo
keys.map('n', 'U', '<C-r>', { desc = 'Redo' })

-- Some editor mappings
keys.map('i', '<C-BS>', '<C-w>', { desc = 'Delete word' })

keys.map('i', '<Tab>', function()
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

keys.map('i', '<S-Tab>', '<C-d>', { desc = 'Unindent' })
keys.map('n', '<Tab>', '>>', { desc = 'Indent' })
keys.map('n', '<S-Tab>', '<<', { desc = 'Indent' })

-- Better page up/down
local function page_expr(dir)
    local jump = vim.api.nvim_win_get_height(0)
    if vim.v.count > 0 then
        jump = jump * vim.v.count
    end

    vim.cmd('normal! ' .. jump .. dir .. 'zz')
end

keys.map({ 'i', 'n' }, '<PageUp>', function()
    page_expr 'k'
end, { desc = 'Page up' })

keys.map({ 'x' }, '<S-PageUp>', function()
    page_expr 'k'
end, { desc = 'Page up' })

keys.map({ 'i', 'n' }, '<PageDown>', function()
    page_expr 'j'
end, { desc = 'Page down' })

keys.map({ 'x' }, '<S-PageDown>', function()
    page_expr 'j'
end, { desc = 'Page down' })

-- Disable the annoying yank on change
keys.map({ 'n', 'x' }, 'c', [["_c]], { desc = 'Change' })
keys.map({ 'n', 'x' }, 'C', [["_C]], { desc = 'Change' })
keys.map('x', 'p', 'P', { desc = 'Paste' })
keys.map('x', 'P', 'p', { desc = 'Yank & paste' })
keys.map('n', 'x', [["_x]], { desc = 'Delete character' })
keys.map('n', '<Del>', [["_x]], { desc = 'Delete character' })
keys.map('x', '<BS>', 'd', { desc = 'Delete selection' })

keys.map('n', 'dd', function()
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

keys.map('n', 'gp', function()
    ins_paste 'o'
end, { desc = 'Paste below' })

keys.map('n', 'gP', function()
    ins_paste 'O'
end, { desc = 'Paste above' })

-- search
keys.map({ 'i', 'n' }, '<esc>', function()
    vim.cmd.nohlsearch()
    if package.loaded['noice'] then
        pcall(vim.cmd.NoiceDismiss)
    end

    return '<esc>'
end, { expr = true, desc = 'Escape and clear highlight' })

keys.map('n', 'n', "'Nn'[v:searchforward].'zv'", { expr = true, desc = 'Next search result' })
keys.map({ 'x', 'o' }, 'n', "'Nn'[v:searchforward]", { expr = true, desc = 'Next search result' })
keys.map('n', 'N', "'nN'[v:searchforward].'zv'", { expr = true, desc = 'Previous search result' })
keys.map({ 'x', 'o' }, 'N', "'nN'[v:searchforward]", { expr = true, desc = 'Previous search result' })

keys.map('n', '\\', 'viw', { desc = 'Select word' })

keys.map('x', '<C-r>', function()
    local text = vim.fn.visual_selected_text()
    keys.feed(syntax.create_rename_expression { orig = text })
end, { desc = 'Replace selection' })

keys.map('x', '<C-S-r>', function()
    local text = vim.fn.visual_selected_text()
    keys.feed(syntax.create_rename_expression { orig = text, whole_word = true })
end, { desc = 'Replace selection (whole word)' })

keys.map('n', '<C-r>', syntax.create_rename_expression(), { desc = 'Replace word under cursor' })
keys.map(
    'n',
    '<C-S-r>',
    syntax.create_rename_expression { whole_word = true },
    { desc = 'Replace word under cursor (whole word)' }
)

-- special keys
keys.map('n', '<M-s>', '<cmd>w<cr>', { desc = 'Save buffer' })
keys.map('n', '<M-x>', 'dd', { desc = 'Delete line' })
keys.map('x', '<M-x>', 'd', { desc = 'Delete selection' })
keys.map('n', '<M-a>', 'ggVG', { desc = 'Select all', remap = true })

keys.map('x', '.', ':norm .<CR>', { desc = 'Repeat edit' })
keys.map('x', '@', ':norm @q<CR>', { desc = 'Repeat macro' })

keys.map('i', '<LeftMouse>', '<Esc><LeftMouse>', { desc = 'Exit insert mode and left-click' })
keys.map('i', '<RightMouse>', '<Esc><RightMouse>', { desc = 'Exit insert mode and right-click' })

keys.map('n', '<C-a>', function()
    if not syntax.increment_node_under_cursor(nil, 1) then
        vim.cmd 'norm! <C-a>'
    end
end, { desc = 'Increment/Toggle value' })

keys.map('n', '<C-x>', function()
    if not syntax.increment_node_under_cursor(nil, -1) then
        vim.cmd 'norm! <C-x>'
    end
end, { desc = 'Decrement/Toggle value' })

-- better search
vim.on_key(function(char)
    if vim.fn.mode() == 'n' then
        local new_hlsearch = vim.tbl_contains({ '<CR>', 'n', 'N', '*', '#', '?', '/' }, vim.fn.keytrans(char))
        if vim.opt.hlsearch ~= new_hlsearch then
            vim.opt.hlsearch = new_hlsearch
        end
    end
end, vim.api.nvim_create_namespace 'auto_hlsearch')

-- show cursor only in active window
events.on_event({ 'InsertLeave', 'WinEnter' }, function(evt)
    if vim.bo[evt.buf].buftype == '' then
        vim.opt_local.cursorline = true
    end
end)

events.on_event({ 'InsertEnter', 'WinLeave' }, function()
    vim.opt_local.cursorline = false
end)

-- highlight on yank
events.on_event('TextYankPost', function()
    vim.highlight.on_yank()
end)

local folds_in_session = vim.list_contains(vim.opt.sessionoptions:get(), 'folds')
if not folds_in_session then
    -- Turn on view generation and loading only if session management is not enabled
    events.on_event({ 'BufWinLeave', 'BufWritePost', 'WinLeave' }, function(evt)
        if settings.get('view_activated', { buffer = evt.buf, scope = 'instance' }) then
            vim.cmd.mkview { mods = { emsg_silent = true } }
        end
    end)

    events.on_event('BufWinEnter', function(evt)
        if not settings.get('view_activated', { buffer = evt.buf, scope = 'instance' }) then
            if not buffers.is_transient_buffer(evt.buf) then
                settings.set('view_activated', true, { buffer = evt.buf, scope = 'instance' })
                vim.cmd.loadview { mods = { emsg_silent = true } }
            end
        end
    end)
end

-- disable swap/undo files for certain file-types
events.on_event('BufWritePre', function(evt)
    vim.opt_local.undofile = false
    if evt.file == 'COMMIT_EDITMSG' or evt.file == 'MERGE_MSG' then
        vim.opt_local.swapfile = false
    end
end, { '/tmp/*', '*.tmp', '*.bak', 'COMMIT_EDITMSG', 'MERGE_MSG' })

-- disable swap/undo/backup files in temp directories or SHM
events.on_event({ 'BufNewFile', 'BufReadPre' }, function()
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

-- Auto create dir when saving a file, in case some intermediate directory does not exist
events.on_event('BufWritePre', function(evt)
    if evt.match:match '^%w%w+://' then
        return
    end

    local file = vim.uv.fs_realpath(evt.match) or evt.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ':p:h'), 'p')
end)

-- forget files that have been deleted
local new_files = {}
events.on_event({ 'BufNew' }, function(evt)
    if buffers.is_special_buffer(evt.buf) then
        return
    end

    local file = vim.api.nvim_buf_get_name(evt.buf)

    if file and file ~= '' and not vim.fs.file_exists(file) then
        new_files[file] = true
    end
end)

events.on_event({ 'BufDelete', 'BufEnter', 'FocusGained' }, function(evt)
    if buffers.is_special_buffer(evt.buf) then
        return
    end

    local file = vim.api.nvim_buf_get_name(evt.buf)
    if not file or file == '' or vim.fs.file_exists(file) then
        return
    end

    if new_files[file] then
        if evt.event == 'BufDelete' then
            new_files[file] = nil
        else
            return
        end
    end

    require('ui.marks').forget(file)
    vim.fn.forget_oldfile(file)
    require('ui.qf').forget(file)

    if evt.event ~= 'BufDelete' then
        vim.cmd 'bdelete!'
    end
end)

-- detect shebangs!
events.on_event('BufReadPost', function(evt)
    if vim.bo[evt.buf].filetype == '' and not buffers.is_special_buffer(evt.buf) then
        local first_line = vim.api.nvim_buf_get_lines(evt.buf, 0, 1, false)[1]
        if
            first_line and string.match(first_line, '^#!.*/bin/bash')
            or string.match(first_line, '^#!.*/bin/env%s+bash')
        then
            vim.bo[evt.buf].filetype = 'bash'
        end
    end
end)

-- additional file types
vim.filetype.add {
    extension = {
        snap = 'javascript',
    },
}
