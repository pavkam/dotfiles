local utils = require 'utils'
local settings = require 'utils.settings'

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

-- go to last loc when opening a buffer
utils.on_event('BufReadPost', function()
    local exclude = { 'gitcommit' }
    local buf = vim.api.nvim_get_current_buf()

    if vim.tbl_contains(exclude, vim.bo[buf].filetype) then
        return
    end

    local mark = vim.api.nvim_buf_get_mark(buf, '"')
    local lcount = vim.api.nvim_buf_line_count(buf)

    if mark[1] > 0 and mark[1] <= lcount then
        pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
end)

-- configure some special buffers
utils.on_event('FileType', function(evt)
    if utils.is_special_buffer(evt.buf) then
        vim.bo[evt.buf].buflisted = false
    end

    if vim.tbl_contains({ 'gitcommit', 'markdown' }, vim.bo[evt.buf].filetype) then
        vim.opt_local.wrap = true
        vim.opt_local.spell = true
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

-- better search
vim.on_key(function(char)
    if vim.fn.mode() == 'n' then
        local new_hlsearch = vim.tbl_contains({ '<CR>', 'n', 'N', '*', '#', '?', '/' }, vim.fn.keytrans(char))
        if vim.opt.hlsearch:get() ~= new_hlsearch then
            vim.opt.hlsearch = new_hlsearch
        end
    end
end, vim.api.nvim_create_namespace 'auto_hlsearch')

-- mkview and loadview for real files
utils.on_event({ 'BufWinLeave', 'BufWritePost', 'WinLeave' }, function(evt)
    if settings.get_permanent_for_buffer(evt.buf, 'view_activated') then
        vim.cmd.mkview { mods = { emsg_silent = true } }
    end
end)

utils.on_event('BufWinEnter', function(evt)
    if not settings.get_permanent_for_buffer(evt.buf, 'view_activated') then
        local filetype = vim.api.nvim_get_option_value('filetype', { buf = evt.buf })
        local buftype = vim.api.nvim_get_option_value('buftype', { buf = evt.buf })
        local ignore_filetypes = { 'gitcommit', 'gitrebase', 'svg', 'hgcommit' }

        if buftype == '' and filetype and filetype ~= '' and not vim.tbl_contains(ignore_filetypes, filetype) then
            settings.set_permanent_for_buffer(evt.buf, 'view_activated', true)
            vim.cmd.loadview { mods = { emsg_silent = true } }
        end
    end
end)

-- file detection commands
utils.on_event({ 'BufReadPost', 'BufNewFile', 'BufWritePost' }, function(evt)
    local current_file = vim.fn.resolve(vim.fn.expand '%')

    -- if custom events have been triggered, bail
    if settings.get_permanent_for_buffer(evt.buf, 'custom_events_triggered') then
        return
    end

    if not utils.is_special_buffer(evt.buf) then
        utils.trigger_user_event 'NormalFile'

        if utils.file_is_under_git(current_file) then
            utils.trigger_user_event 'GitFile'
        end
    end

    -- do not retrigger these events if the file name is set
    if current_file ~= '' then
        settings.set_permanent_for_buffer(evt.buf, 'custom_events_triggered', true)
    end
end)

-- TODO: detect shell file type using shebang (#!)
-- https://www.reddit.com/r/neovim/comments/17q3qmd/autodetecting_filetype_from_shebang/
