if not vim.fn.executable 'git' then
    error 'fatal: git required'
    vim.api.nvim_command 'cq1'

    return
end

if not vim.fn.has 'nvim-9.4' then
    error 'fatal: minimum required Neovim version is 0.9.4'
    vim.api.nvim_command 'cq1'

    return
end

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

-- TODO: figure out why LSP diagnostics get borked

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
        spec = vim.tbl_map(function(module)
            return { import = module .. '/plugins' }
        end, modules),
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
end
