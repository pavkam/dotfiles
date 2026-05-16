-- Neovim 0.12 IDE configuration
-- OOP layer: _G.IDE singleton + extension system
-- Completion: native vim.lsp.completion + LuaSnip + Supermaven
-- LSP: native vim.lsp.config() + vim.lsp.enable()
require 'init'

-- Minimum version check
if vim.fn.has('nvim-0.12') ~= 1 then
    vim.api.nvim_echo({ { 'IDE requires Neovim 0.12+', 'ErrorMsg' } }, true, {})
    return
end
if vim.fn.executable('git') ~= 1 then
    vim.api.nvim_echo({ { 'IDE requires git', 'ErrorMsg' } }, true, {})
    return
end

require 'options'

-- Setup the Lazy plugin manager
local plugin = require 'plugin'
local data_path = vim.fn.stdpath('data') --[[@as string]]
plugin.require_online('https://github.com/folke/lazy.nvim.git', vim.fs.joinpath(data_path, 'lazy', 'lazy.nvim'))

require('lazy').setup {
    spec = { import = 'plugins' },
    defaults = {
        lazy = true,
        version = false,
    },
    ui = {
        border = vim.g.border_style,
    },
    change_detection = {
        enabled = false,
    },
    checker = {
        enabled = true,
        notify = false,
    },
    install = {
        colorscheme = { 'default' },
    },
    performance = {
        rtp = {
            disabled_plugins = {
                'rplugin',
                'matchit',
                'netrwPlugin',
                'man',
                'tutor',
                'health',
                'tohtml',
                'gzip',
                'zipPlugin',
                'tarPlugin',
            },
        },
    },
}

-- Apply owned TurboVision colorscheme
pcall(require, 'ide.theme')
pcall(function() require('ide.theme').apply() end)

-- OOP layer: creates the IDE singleton (sets _G.IDE internally during init)
local ide_ok, ide_err = pcall(require, 'ide')
if not ide_ok then
    vim.schedule(function()
        vim.notify('[IDE] Boot failed: ' .. tostring(ide_err), vim.log.levels.ERROR)
    end)
end

-- Open file explorer when opening a directory
vim.api.nvim_create_autocmd('User', {
    pattern = 'LazyVimStarted',
    callback = function()
        if not _G.IDE then return end
        local opening_a_dir = vim.fn.argc() == 1 and IDE.fs:is_directory(vim.fn.argv(0) --[[@as string]])
        if opening_a_dir then
            vim.schedule(function()
                pcall(function() IDE.ui.tree:toggle() end)
            end)
        end
    end,
})

