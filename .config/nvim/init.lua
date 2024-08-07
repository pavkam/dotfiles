-- LOW: figure out why TODOs don't get highlighted
-- LOW: show the number of failed/total tests in the status-line
-- TODO: the typos lsp is not dying correctly when disabled
-- TODO: fixwin fails in many cases, probably need to be very specific,
-- TODO: Alpha appears when it should not
-- URGENT: Do not use which key if there is no icon attached.
-- MAYBE: Cross-tmux-session marks

require 'extensions'

if not vim.fn.executable 'git' then
    fatal 'git required'
    return
end

if not vim.fn.has 'nvim-0.10' then
    fatal 'minimum required Neovim version is 0.10'
    return
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

require 'core.options'

-- Setup the Lazy plugin manager
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
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

---@type string[]
local plugin_dirs = vim.iter(modules)
    :map(
        ---@param module string
        function(module)
            return module .. '/plugins'
        end
    )
    :filter(
        ---@param dir string
        function(dir)
            return vim.fn.isdirectory(config_path .. '/lua/' .. dir) == 1
        end
    )
    :totable()

require('lazy').setup {
    spec = vim.iter(plugin_dirs)
        :map(
            ---@param dir string
            function(dir)
                return { import = dir }
            end
        )
        :totable(),
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
        colorscheme = { 'tokyonight' },
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

--- Load all modules
---@type table<string, any>
local load_errors = {}
for _, module in ipairs(modules) do
    local ok, err = pcall(require, module)

    if not ok then
        load_errors[module] = err
    end
end

-- For any errors, print them out after the editor has started
if next(load_errors) then
    vim.api.nvim_create_autocmd('User', {
        pattern = 'LazyVimStarted',
        callback = function()
            for module, err in pairs(load_errors) do
                vim.api.nvim_err_writeln('Error loading "' .. module .. '": ' .. vim.inspect(err))
            end
        end,
    })
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
