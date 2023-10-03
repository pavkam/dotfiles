-- Auto-commands for a better life
local utils = require 'utils'

utils.auto_command('TextYankPost', function() vim.highlight.on_yank() end, '*');
