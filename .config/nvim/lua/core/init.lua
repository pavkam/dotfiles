local utils = require 'core.utils'

require 'core.forget'
require 'core.options'
require 'core.shell'

-- common misspellings
vim.cmd.cnoreabbrev('qw', 'wq')
vim.cmd.cnoreabbrev('Wq', 'wq')
vim.cmd.cnoreabbrev('WQ', 'wq')
vim.cmd.cnoreabbrev('Qa', 'qa')
vim.cmd.cnoreabbrev('Bd', 'bd')
vim.cmd.cnoreabbrev('bD', 'bd')

-- check if the file has been changed outside of neovim
utils.on_event({ 'FocusGained', 'TermClose', 'TermLeave' }, function()
    vim.cmd.checktime()
end)

-- Auto create dir when saving a file, in case some intermediate directory does not exist
utils.on_event('BufWritePre', function(evt)
    if evt.match:match '^%w%w+://' then
        return
    end

    local file = vim.loop.fs_realpath(evt.match) or evt.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ':p:h'), 'p')
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

vim.keymap.set('n', '<leader>L', function()
    utils.info(vim.inspect(require('core.old_files').all()))
end, { desc = 'pula@' })
