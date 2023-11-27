require 'options'
require 'keymaps'
require 'commands'

-- Setup the Lazy plugin manager
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system {
        'git',
        'clone',
        '--filter=blob:none',
        'https://github.com/folke/lazy.nvim.git',
        '--branch=stable', -- latest stable release
        lazypath,
    }
end

vim.opt.rtp:prepend(lazypath)

require('lazy').setup {
    spec = {
        { import = 'plugins' },
    },
    defaults = {
        lazy = true,
        version = false,
    },
    ui = {
        border = 'rounded',
    },
    checker = {
        enabled = true,
        notify = false,
    },
    install = { colorscheme = { 'tokyonight', 'catppuccin', 'habamax' } },
    performance = {
        rtp = {
            disabled_plugins = {
                'gzip',
                'matchit',
                -- "matchparen",
                'netrwPlugin',
                'tarPlugin',
                'tohtml',
                'tutor',
                'zipPlugin',
            },
        },
    },
}

require 'auto-commands'

vim.cmd.colorscheme 'tokyonight'
