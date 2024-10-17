-- MAYBE: jump to buf (https://github.com/catgoose/templ-goto-definition/blob/main/lua/templ-goto-definition/init.lua)
--
-- LOW: Evaluate difftastic
-- LOW: refactor the core module to be more modular
-- LOW: Evaluate grug-far
--      (https://www.reddit.com/r/neovim/comments/1f4al0o/grugfarnvim_update_multiline_input_and_telescope/)
-- LOW: integrate with "cSpell.words" in .vscode/settings.json
-- LOW: rework the shell module or drop it in favor or buitin nvim code.
--
-- TODO: improve the mouse right-click: https://github.com/neovim/neovim/commit/76aa3e52be7a5a8b53b3775981c35313284230ac
-- TODO: Use copilot to describe vim commands with suggestions: https://github.com/oflisback/describe-command.nvim/blob/main/lua/describe-command/commands.lua
-- TODO: record error messages into a debug file
-- TODO: ability to select the root of the project
-- TODO: the [No Name] is not getting the fuck out when I select a file
-- TODO: typos lsp has issues when disabled. Not sure how to deal with it at the moment.
-- TODO: the CopilotChat buffer is not detached properly and gets reloaded as a buffer in session.
-- TODO: lazy-git, use custom spinner
-- TODO: disable 'u' and 'U' in visual mode, just annoying
-- TODO: expose the group for the mapping of keys (refactor keys module)
-- TODO: package-info is crap, make a smaller one just to show versions and if module is deprecated.

require 'api'

if not vim.fn.executable 'git' then
    fatal 'git required'
    return
end

if not vim.fn.has 'nvim-0.10' then
    fatal 'minimum required Neovim version is 0.10'
    return
end

vim.headless = vim.list_contains(vim.api.nvim_get_vvar 'argv', '--headless') or #vim.api.nvim_list_uis() == 0

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
local lazypath = vim.fs.joinpath(vim.fs.data_dir, 'lazy', 'lazy.nvim')
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

---@type string[]
local plugin_dirs = vim.iter(modules)
    :map(
        ---@param module string
        function(module)
            return vim.fs.joinpath(module, 'plugins')
        end
    )
    :filter(
        ---@param dir string
        function(dir)
            return vim.fs.dir_exists(vim.fs.joinpath(vim.fs.config_dir, 'lua', dir))
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

-- Post-load hook
vim.api.nvim_create_autocmd('User', {
    pattern = 'LazyVimStarted',
    callback = function()
        for module, err in pairs(load_errors) do
            vim.api.nvim_err_writeln('Error loading "' .. module .. '": ' .. vim.inspect(err))
        end

        local opening_a_dir = vim.fn.argc() == 1 and vim.fs.dir_exists(vim.fn.argv(0) --[[@as string]])

        if opening_a_dir then
            require 'neo-tree'
        end
    end,
})
