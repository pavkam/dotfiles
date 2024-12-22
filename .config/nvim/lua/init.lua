require 'shell'
require 'sessions'
require 'project'
require 'settings'
require 'lsp'
require 'debugging'
require 'neotest'
require 'health'
require 'lsp'
require 'extras'
require 'marks'
require 'qf'
require 'tmux'
require 'file-palette'
require 'spelling'
require 'comments'

local events = require 'events'
local keys = require 'keys'
local syntax = require 'syntax'
local git = require 'git'
local icons = require 'icons'
local progress = require 'progress'

-- additional file types
vim.filetype.add {
    extension = {
        snap = 'javascript',
    },
    pattern = {
        ['.env'] = 'bash',
        ['.env.*'] = 'bash',
    },
}

ide.ft['help'].pinned_to_window = true
ide.ft['query'].pinned_to_window = true
ide.ft['markdown'].wrap_enabled = true
ide.ft['gitcommit'].wrap_enabled = true
ide.ft['gitrebase'].wrap_enabled = true
ide.ft['hgcommit'].wrap_enabled = true

-- common misspellings
vim.cmd.cnoreabbrev('qw', 'wq')
vim.cmd.cnoreabbrev('Wq', 'wq')
vim.cmd.cnoreabbrev('WQ', 'wq')
vim.cmd.cnoreabbrev('Qa', 'qa')
vim.cmd.cnoreabbrev('Bd', 'bd')
vim.cmd.cnoreabbrev('bD', 'bd')

vim.cmd [[
aunmenu PopUp.How-to\ disable\ mouse
aunmenu PopUp.-1-
]]

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
    local text = ide.win[vim.api.nvim_get_current_win()].selected_text
    keys.feed(syntax.create_rename_expression { orig = text })
end, { desc = 'Replace selection' })

keys.map('x', '<C-S-r>', function()
    local text = ide.win[vim.api.nvim_get_current_win()].selected_text
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
    if not syntax.increment_node(1) then
        vim.cmd 'norm! <C-a>'
    end
end, { desc = 'Increment/Toggle value' })

keys.map('n', '<C-x>', function()
    if not syntax.increment_node(-1) then
        vim.cmd 'norm! <C-x>'
    end
end, { desc = 'Decrement/Toggle value' })

keys.map({ 'n', 'x' }, '=', function()
    local buffer = require('api.buf').current
    if buffer and buffer.is_normal then
        buffer.format()
    end
end, { desc = 'Format buffer/selection' })

-- better search
vim.on_key(function(char)
    if vim.fn.mode() == 'n' then
        local new_hlsearch = vim.tbl_contains({ '<CR>', 'n', 'N', '*', '#', '?', '/' }, vim.fn.keytrans(char))
        if vim.opt.hlsearch ~= new_hlsearch then
            vim.opt.hlsearch = new_hlsearch
        end
    end
end, vim.api.nvim_create_namespace 'auto_hlsearch')

keys.group { lhs = 'g', mode = { 'n', 'v' }, icon = icons.UI.Next, desc = 'Go-to' }
keys.group { lhs = ']', mode = { 'n', 'v' }, icon = icons.UI.Next, desc = 'Next' }
keys.group { lhs = '[', mode = { 'n', 'v' }, icon = icons.UI.Prev, desc = 'Previous' }

-- Disable some sequences
keys.map({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })
keys.map('n', '<BS>', '<Nop>', { silent = true })
keys.map('n', '<M-v>', '<cmd>wincmd v<CR>', { desc = 'Split window below' })
keys.map('n', '<M-h>', '<cmd>wincmd s<CR>', { desc = 'Split window right' })

-- Better jump list navigation
keys.map('n', ']]', '<C-i>', { desc = 'Next location' })
keys.map('n', '[[', '<C-o>', { desc = 'Previous location' })

-- terminal mappings
keys.map('t', '<esc><esc>', '<c-\\><c-n>', { desc = 'Enter normal mode' })

-- buffer management
keys.map('n', '<leader><leader>', function()
    if not vim.buf.is_special() then
        pcall(vim.cmd.edit, '#')
    end
end, { icon = icons.UI.Switch, desc = 'Switch buffer', silent = true })

keys.map('n', '<leader>c', function()
    ide.buf[vim.api.nvim_get_current_buf()].remove()
end, { icon = icons.UI.Close, desc = 'Close buffer' })
keys.map('n', '<leader>C', function()
    ide.buf[vim.api.nvim_get_current_buf()].remove_others()
end, { icon = icons.UI.Close, desc = 'Close other buffers' })

for i = 1, 9 do
    keys.map('n', '<M-' .. i .. '>', function()
        local buffer = vim.buf.get_listed_buffers({ loaded = false })[i]
        if buffer then
            vim.cmd.buffer(buffer)
        end
    end, { desc = 'Go to buffer ' .. i })
end

keys.map('n', '<leader>w', '<cmd>w<cr>', { icon = icons.UI.Save, desc = 'Save buffer' })
keys.map('n', '<leader>W', '<cmd>wa<cr>', { icon = icons.UI.SaveAll, desc = 'Save all buffers' })

keys.map('n', '[b', '<cmd>bprevious<cr>', { icon = icons.UI.Next, desc = 'Previous buffer' })
keys.map('n', ']b', '<cmd>bnext<cr>', { icons = icons.UI.Prev, desc = 'Next buffer' })

-- tabs
keys.map('n', ']t', '<cmd>tabnext<cr>', { icon = icons.UI.Next, desc = 'Next tab' })
keys.map('n', '[t', '<cmd>tabprevious<cr>', { icons = icons.UI.Prev, desc = 'Previous tab' })

-- diagnostics
keys.map('n', ']m', function()
    ide.buf.current.next_diagnostic(true)
end, { icon = icons.UI.Next, desc = 'Next Diagnostic' })
keys.map('n', '[m', function()
    ide.buf.current.next_diagnostic(false)
end, { icon = icons.UI.Prev, desc = 'Previous Diagnostic' })
keys.map('n', ']e', function()
    ide.buf.current.next_diagnostic(true, 'ERROR')
end, { icon = icons.UI.Next, desc = 'Next Error' })
keys.map('n', '[e', function()
    ide.buf.current.next_diagnostic(false, 'ERROR')
end, { icon = icons.UI.Prev, desc = 'Previous Error' })
keys.map('n', ']w', function()
    ide.buf.current.next_diagnostic(true, 'WARN')
end, { icon = icons.UI.Next, desc = 'Next Warning' })
keys.map('n', '[w', function()
    ide.buf.current.next_diagnostic(false, 'WARN')
end, { icon = icons.UI.Prev, desc = 'Previous Warning' })

-- Command mode remaps to make my life easier using the keyboard
keys.map('c', '<Down>', function()
    if vim.fn.wildmenumode() then
        return '<C-n>'
    else
        return '<Down>'
    end
end, { expr = true })

keys.map('c', '<Up>', function()
    if vim.fn.wildmenumode() then
        return '<C-p>'
    else
        return '<Up>'
    end
end, { expr = true })

keys.map('c', '<Left>', function()
    if vim.fn.wildmenumode() then
        return '<Space><BS><Left>'
    else
        return '<Left>'
    end
end, { expr = true })

keys.map('c', '<Right>', function()
    if vim.fn.wildmenumode() then
        return '<Space><BS><Right>'
    else
        return '<Right>'
    end
end, { expr = true })

-- Add "q" to special windows
keys.attach(vim.buf.special_file_types, function(set)
    set('n', 'q', '<cmd>close<cr>', { silent = true })
    set('n', '<Esc>', '<cmd>close<cr>', { silent = true })
end)

keys.attach('help', function(set)
    set('n', 'q', '<cmd>close<cr>', { icon = icons.UI.Close, silent = true })
    set('n', '<Esc>', '<cmd>close<cr>', { icon = icons.UI.Close, silent = true })
end, true)

keys.attach(nil, function(set)
    keys.group { mode = 'n', icon = icons.UI.AI, lhs = '<leader>x', desc = 'AI' }

    set('n', '<leader>xx', function()
        require('CopilotChat').open()
    end, { desc = 'Open chat window', icon = icons.UI.Tool })

    set('n', '<leader>xa', function()
        require('CopilotChat').select_agent()
    end, { desc = 'Select agent', icon = icons.UI.Tool })

    set('n', '<leader>xm', function()
        require('CopilotChat').select_model()
    end, { desc = 'Select model', icon = icons.UI.Tool })

    set('n', '<leader>xf', function()
        require('CopilotChat').ask('Fix the code in the file', {
            context = '#buffer',
            clear_chat_on_new_prompt = true,
            auto_insert_mode = false,
            window = {
                layout = 'float',
                relative = 'cursor',
                width = 1,
                height = 0.4,
                row = 1,
            },
        })
    end, { desc = 'Chat with AI', icon = icons.UI.AI })
end)

keys.map('n', '<leader>u', require('api.config').manage, { icon = icons.UI.UI, desc = 'Manage options' })

-- Specials using "Command/Super" key (when available!)
keys.map('n', '<M-]>', '<C-i>', { icon = icons.UI.Next, desc = 'Next location' })
keys.map('n', '<M-[>', '<C-o>', { icon = icons.UI.Prev, desc = 'Previous location' })

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
        local option = ide.config.use('view_activated', { buffer = ide.buf[evt.buf], persistent = false })
        if option.get() then
            vim.cmd.mkview { mods = { emsg_silent = true } }
        end
    end)

    events.on_event('BufWinEnter', function(evt)
        local option = ide.config.use('view_activated', { buffer = ide.buf[evt.buf], persistent = false })

        if not option.get() then
            if not vim.buf.is_transient(evt.buf) then
                option.set(true)
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

-- Forget files that have been deleted
local new_files = {}
events.on_event({ 'BufNew' }, function(evt)
    if vim.buf.is_special(evt.buf) then
        return
    end

    local file = vim.api.nvim_buf_get_name(evt.buf)

    if file and file ~= '' and not ide.fs.file_exists(file) then
        new_files[file] = true
    end
end)

events.on_event({ 'BufDelete', 'BufEnter', 'FocusGained' }, function(evt)
    if vim.buf.is_special(evt.buf) then
        return
    end

    local file = vim.api.nvim_buf_get_name(evt.buf)
    if not file or file == '' or ide.fs.file_exists(file) then
        return
    end

    if new_files[file] then
        if evt.event == 'BufDelete' then
            new_files[file] = nil
        else
            return
        end
    end

    require('marks').forget(file)
    vim.fn.forget_oldfile(file)
    require('qf').forget(file)

    if evt.event ~= 'BufDelete' then
        vim.cmd 'bdelete!'
    end
end)

-- Restore cursor position after opening a file
events.on_event({ 'BufReadPost', 'BufNew' }, function(evt)
    if vim.buf.is_special(evt.buf) or vim.buf.is_transient(evt.buf) then
        return
    end

    local cursor_mark = vim.api.nvim_buf_get_mark(evt.buf, '"')
    if cursor_mark[1] > 0 and cursor_mark[1] <= vim.api.nvim_buf_line_count(evt.buf) then
        pcall(vim.api.nvim_win_set_cursor, 0, cursor_mark)
    end
end)

-- TODO: move this into vim.filetype
-- detect shebangs!
events.on_event('BufReadPost', function(evt)
    if vim.bo[evt.buf].filetype == '' and not vim.buf.is_special(evt.buf) then
        local first_line = vim.api.nvim_buf_get_lines(evt.buf, 0, 1, false)[1]
        if
            first_line and string.match(first_line, '^#!.*/bin/bash')
            or string.match(first_line, '^#!.*/bin/env%s+bash')
        then
            vim.bo[evt.buf].filetype = 'bash'
        end
    end
end)

-- Check if the file has been changed outside of Neovim
ide.process.on_focus(function()
    local buffer = vim.api.nvim_get_current_buf()

    if vim.buf.is_regular(buffer) then
        vim.cmd.checktime() --TODO: use FileChangedShell to do all the whacky stuff
    end
end)

events.on_event({ 'CursorHold', 'CursorHoldI' }, function(evt)
    if vim.buf.is_regular(evt.buf) then
        vim.cmd.checktime()
    end
end)

---@module 'api.buf'
---
-- file detection commands
events.on_event({ 'BufReadPost', 'BufNewFile', 'BufWritePost' }, function(evt)
    local buffer = ide.buf[
        evt.buf --[[@as integer]]
    ]

    if buffer and buffer.is_normal then
        local option = ide.config.use('custom_events_triggered', { buffer = buffer, persistent = false })

        -- if custom events have been triggered, bail
        if option.get() or buffer.file_path == '' then
            return
        end

        events.trigger_user_event 'NormalFile'

        git.check_tracked(buffer.file_path, function(yes)
            if yes then
                events.trigger_user_event 'GitFile'
            end
        end)

        option.set(true)
    end
end)

-- resize splits if window got resized
events.on_event('VimResized', function()
    vim.schedule(function()
        ide.tui.redraw()
        events.trigger_status_update_event()
    end)
end)

--- Macro tracking
events.on_event({ 'RecordingEnter' }, function()
    ide.tui.info(
        string.format(
            'Started recording macro into register `%s`',
            vim.fn.reg_recording(),
            { prefix_icon = icons.UI.Macro, suffix_icon = icons.TUI.Ellipsis }
        )
    )

    progress.update('recording_macro', {
        fn = function()
            return vim.fn.reg_recording() ~= ''
        end,
        desc = 'Recording macro',
        ctx = vim.fn.reg_recording(),
        timeout = math.huge,
    })
end)

events.on_event({ 'RecordingLeave' }, function()
    ide.tui.info(
        string.format(
            'Stopped recording macro into register `%s`',
            vim.fn.reg_recording(),
            { prefix_icon = icons.UI.Checkmark, suffix_icon = icons.TUI.Ellipsis }
        )
    )

    progress.stop 'recording_macro'
end)
