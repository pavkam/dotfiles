--- Cheks the level of features supported by the current Neovim instance
---@param level 0|1|2|3 # the level to check for
---@return boolean # whether the current Neovim instance supports the given feature level
_G.feature_level = function(level)
    -- check environment variable NVIM_FEATURE_LEVEL for feature level
    -- if not set, assume level 3. Valid levels:
    -- 0: nothing
    -- 1: minimal
    -- 2: basic
    -- 3: full

    local env_level = tonumber(vim.env.NVIM_FEATURE_LEVEL) or 3
    return env_level >= level
end

-- TODO: support for sessions per folder / branch (see recession maybe)
-- TODO: figure out why LSP diagnostics get borked
require 'options'
require 'commands'

if feature_level(1) then
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

    require 'marks'
    require 'core'
    require 'file_types'
    require 'search'
    require 'extras'
    require 'notes'
    require 'qf'

    vim.cmd.colorscheme 'tokyonight'
    require 'highlights'
end
