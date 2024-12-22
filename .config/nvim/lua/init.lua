require 'ui'
require 'shell'
require 'sessions'
require 'project'
require 'settings'
require 'lsp'
require 'debugging'
require 'progress'
require 'keys'
require 'neotest'
require 'health'
require 'git'
require 'editor'
require 'lsp'
require 'extras'

-- common misspellings
vim.cmd.cnoreabbrev('qw', 'wq')
vim.cmd.cnoreabbrev('Wq', 'wq')
vim.cmd.cnoreabbrev('WQ', 'wq')
vim.cmd.cnoreabbrev('Qa', 'qa')
vim.cmd.cnoreabbrev('Bd', 'bd')
vim.cmd.cnoreabbrev('bD', 'bd')

local events = require 'events'

-- Check if the file has been changed outside of Neovim
ide.process.on_focus(function()
    local buffer = vim.api.nvim_get_current_buf()

    vim.api.nvim_buf_get_changedtick(buffer)
    if vim.buf.is_regular(buffer) then
        vim.cmd.checktime() --TODO: use FileChangedShell to do all the whacky stuff
    end
end)

events.on_event({ 'CursorHold', 'CursorHoldI' }, function(evt)
    if vim.buf.is_regular(evt.buf) then
        vim.cmd.checktime()
    end
end)
