if not vim.fn.executable 'git' then
    error 'fatal: git required'
    vim.api.nvim_command 'cq1'

    return
end

if not vim.fn.has 'nvim-0.10' then
    error 'fatal: minimum required Neovim version is 0.10'
    vim.api.nvim_command 'cq1'

    return
end

--- Global debug function to help me debug (duh)
---@vararg any anything to debug
_G.dbg = function(...)
    local objects = {}
    for _, v in pairs { ... } do
        local val = v ~= nil and vim.inspect(v) or 'nil'
        table.insert(objects, val)
    end

    local message = table.concat(objects, '\n')

    vim.notify(message)
end

local modules = {
    'core',
    'ui',
    'editor',
    'testing',
    'git',
    'project',
    'debugging',
    'formatting',
    'linting',
    'extras',
}

require 'core'

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

---@diagnostic disable-next-line: undefined-field
vim.opt.rtp:prepend(lazypath)

local config_path = vim.fn.stdpath 'config'
local plugin_dirs = vim.tbl_filter(
    function(dir)
        return vim.fn.isdirectory(config_path .. '/lua/' .. dir) == 1
    end,
    vim.tbl_map(function(module)
        return module .. '/plugins'
    end, modules)
)

require('lazy').setup {
    spec = vim.tbl_map(function(dir)
        return { import = dir }
    end, plugin_dirs),
    defaults = {
        lazy = true,
        version = false,
    },
    ui = {
        border = vim.g.border_style,
    },
    checker = {
        enabled = true,
        notify = false,
    },
    install = { colorscheme = { 'tokyonight', 'catppuccin', 'habamax' } },
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

for _, module in ipairs(modules) do
    local ok, err = pcall(require, module)

    if not ok then
        vim.api.nvim_err_writeln('Error loading ' .. module .. ': ' .. err)
    end
end

-- open neo-tree if opening a directory
local opening_a_dir = vim.fn.argc() == 1 and vim.fn.isdirectory(vim.fn.argv(0) --[[@as string]]) == 1
if opening_a_dir then
    vim.api.nvim_create_autocmd('User', {
        pattern = 'LazyVimStarted',
        callback = function()
            require 'neo-tree'
        end,
    })
end
