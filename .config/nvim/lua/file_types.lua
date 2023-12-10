local utils = require 'utils'
local settings = require 'utils.settings'
local shell = require 'utils.shell'

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

-- file detection commands
utils.on_event({ 'BufReadPost', 'BufNewFile', 'BufWritePost' }, function(evt)
    local current_file = vim.api.nvim_buf_get_name(evt.buf)

    -- if custom events have been triggered, bail
    if settings.get('custom_events_triggered', { buffer = evt.buf }) then
        return
    end

    if not utils.is_special_buffer(evt.buf) then
        utils.trigger_user_event 'NormalFile'

        shell.check_file_is_tracked_by_git(vim.loop.fs_realpath(current_file) or current_file, function(yes)
            if yes then
                utils.trigger_user_event 'GitFile'
            end
        end)
    end

    -- do not retrigger these events if the file name is set
    if current_file ~= '' then
        settings.set('custom_events_triggered', true, { buffer = evt.buf })
    end
end)

-- detect shebangs!
utils.on_event('BufReadPost', function(evt)
    if vim.bo[evt.buf].filetype == '' and not utils.is_special_buffer(evt.buf) then
        local first_line = vim.api.nvim_buf_get_lines(evt.buf, 0, 1, false)[1]
        if first_line and string.match(first_line, '^#!.*/bin/bash') or string.match(first_line, '^#!.*/bin/env%s+bash') then
            vim.bo[evt.buf].filetype = 'bash'
        end
    end
end)
