require 'core.options'
require 'core.shell'
require 'core.sessions'

-- common misspellings
vim.cmd.cnoreabbrev('qw', 'wq')
vim.cmd.cnoreabbrev('Wq', 'wq')
vim.cmd.cnoreabbrev('WQ', 'wq')
vim.cmd.cnoreabbrev('Qa', 'qa')
vim.cmd.cnoreabbrev('Bd', 'bd')
vim.cmd.cnoreabbrev('bD', 'bd')

local events = require 'core.events'

-- Check if the file has been changed outside of Neovim
events.on_focus_gained(function()
    vim.cmd.checktime()
end)

events.on_event({ 'CursorHold', 'CursorHoldI' }, function()
    vim.cmd.checktime()
end)
