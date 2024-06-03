local utils = require 'core.utils'
local icons = require 'ui.icons'
local settings = require 'core.settings'
local syntax = require 'editor.syntax'

require 'editor.comments'
require 'editor.snippets'

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
for _, key in ipairs { '.', ',', '!', '?', ';', ':', '"', "'" } do
    vim.keymap.set('i', key, string.format('%s<c-g>u', key), { desc = string.format('Insert %s and an undo break-point', key) })
end

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
vim.keymap.set({ 'i', 'n' }, '<esc>', function()
    vim.cmd.nohlsearch()
    if package.loaded['noice'] then
        vim.cmd.NoiceDismiss()
    end

    return '<esc>'
end, { expr = true, desc = 'Escape and clear highlight' })

vim.keymap.set('n', 'n', "'Nn'[v:searchforward].'zv'", { expr = true, desc = 'Next search result' })
vim.keymap.set({ 'x', 'o' }, 'n', "'Nn'[v:searchforward]", { expr = true, desc = 'Next search result' })
vim.keymap.set('n', 'N', "'nN'[v:searchforward].'zv'", { expr = true, desc = 'Previous search result' })
vim.keymap.set({ 'x', 'o' }, 'N', "'nN'[v:searchforward]", { expr = true, desc = 'Previous search result' })

vim.keymap.set('n', '\\', 'viw', { desc = 'Select word' })

vim.keymap.set('x', '<C-r>', function()
    local text = utils.get_selected_text()
    utils.feed_keys(syntax.create_rename_expression { orig = text })
end, { desc = 'Replace selection' })

vim.keymap.set('x', '<C-S-r>', function()
    local text = utils.get_selected_text()
    utils.feed_keys(syntax.create_rename_expression { orig = text, whole_word = true })
end, { desc = 'Replace selection (whole word)' })

vim.keymap.set('n', '<C-r>', syntax.create_rename_expression(), { desc = 'Replace word under cursor' })
vim.keymap.set('n', '<C-S-r>', syntax.create_rename_expression { whole_word = true }, { desc = 'Replace word under cursor (whole word)' })

-- special keys
vim.keymap.set('n', '<M-s>', '<cmd>w<cr>', { desc = 'Save buffer' })
vim.keymap.set('n', '<M-x>', 'dd', { desc = 'Delete line' })
vim.keymap.set('x', '<M-x>', 'd', { desc = 'Delete selection' })
vim.keymap.set('n', '<M-a>', 'ggVG', { desc = 'Select all', remap = true })

vim.keymap.set('x', '.', ':norm .<CR>', { desc = 'Repeat edit' })
vim.keymap.set('x', '@', ':norm @q<CR>', { desc = 'Repeat macro' })

vim.keymap.set('i', '<LeftMouse>', '<Esc><LeftMouse>', { desc = 'Exit insert mode and left-click' })
vim.keymap.set('i', '<RightMouse>', '<Esc><RightMouse>', { desc = 'Exit insert mode and right-click' })

vim.keymap.set('n', '<C-a>', function()
    if not syntax.increment_node_under_cursor(nil, 1) then
        vim.cmd 'norm! <C-a>'
    end
end, { desc = 'Increment/Toggle value' })

vim.keymap.set('n', '<C-x>', function()
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

local folds_in_session = vim.list_contains(vim.opt.sessionoptions:get(), 'folds')
if folds_in_session then
    -- Turn on view generation and loading only if session management is not enabled
    utils.on_event({ 'BufWinLeave', 'BufWritePost', 'WinLeave' }, function(evt)
        if settings.get('view_activated', { buffer = evt.buf, scope = 'instance' }) then
            vim.cmd.mkview { mods = { emsg_silent = true } }
        end
    end)

    utils.on_event('BufWinEnter', function(evt)
        if not settings.get('view_activated', { buffer = evt.buf, scope = 'instance' }) then
            if not utils.is_transient_buffer(evt.buf) then
                settings.set('view_activated', true, { buffer = evt.buf, scope = 'instance' })
                vim.cmd.loadview { mods = { emsg_silent = true } }
            end
        end
    end)
end

-- disable swap/undo files for certain file-types
utils.on_event('BufWritePre', function(evt)
    vim.opt_local.undofile = false
    if evt.file == 'COMMIT_EDITMSG' or evt.file == 'MERGE_MSG' then
        vim.opt_local.swapfile = false
    end
end, { '/tmp/*', '*.tmp', '*.bak', 'COMMIT_EDITMSG', 'MERGE_MSG' })

-- disable swap/undo/backup files in temp directories or SHM
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

-- Auto create dir when saving a file, in case some intermediate directory does not exist
utils.on_event('BufWritePre', function(evt)
    if evt.match:match '^%w%w+://' then
        return
    end

    local file = vim.loop.fs_realpath(evt.match) or evt.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ':p:h'), 'p')
end)

-- forget files that have been deleted
local new_files = {}
utils.on_event({ 'BufNew' }, function(evt)
    if utils.is_special_buffer(evt.buf) then
        return
    end

    local file = vim.api.nvim_buf_get_name(evt.buf)

    if file and file ~= '' and not utils.file_exists(file) then
        new_files[file] = true
    end
end)

utils.on_event({ 'BufDelete', 'BufEnter', 'FocusGained' }, function(evt)
    if utils.is_special_buffer(evt.buf) then
        return
    end

    local file = vim.api.nvim_buf_get_name(evt.buf)
    if not file or file == '' or utils.file_exists(file) then
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
    require('core.old_files').forget(file)
    require('ui.qf').forget(file)

    if evt.event ~= 'BufDelete' then
        vim.cmd 'bdelete!'
    end
end)

settings.register_toggle('spelling', function(enabled)
    ---@diagnostic disable-next-line: undefined-field
    vim.opt.spell = enabled

    local all = vim.lsp.get_clients { name = 'typos_lsp' }
    if #all == 1 then
        local client = all[1]
        if enabled then
            vim.lsp.buf_attach_client(0, client.id)
        else
            vim.lsp.stop_client(client.id, true)
        end
    end

    ---@diagnostic disable-next-line: undefined-field
end, { name = icons.UI.SpellCheck .. ' Spell checking', default = vim.opt.spell:get(), scope = 'global' })

-- detect shebangs!
utils.on_event('BufReadPost', function(evt)
    if vim.bo[evt.buf].filetype == '' and not utils.is_special_buffer(evt.buf) then
        local first_line = vim.api.nvim_buf_get_lines(evt.buf, 0, 1, false)[1]
        if first_line and string.match(first_line, '^#!.*/bin/bash') or string.match(first_line, '^#!.*/bin/env%s+bash') then
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
