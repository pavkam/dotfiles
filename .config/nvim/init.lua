-- MAYBE: jump to buf (https://github.com/catgoose/templ-goto-definition/blob/main/lua/templ-goto-definition/init.lua)
--
-- LOW: Evaluate difftastic
-- LOW: refactor the core module to be more modular
-- LOW: Evaluate grug-far
--      (https://www.reddit.com/r/neovim/comments/1f4al0o/grugfarnvim_update_multiline_input_and_telescope/)
-- LOW: integrate with "cSpell.words" in .vscode/settings.json
-- LOW: rework the shell module or drop it in favor or built-in nvim code.
-- LOW: Maybe find a way to configure semantic tokens to avoid comments and string literals:
--      https://gist.github.com/swarn/fb37d9eefe1bc616c2a7e476c0bc0316#controlling-when-highlights-are-applied.
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
    ide.process.fatal 'git required'
    return
end

if not vim.fn.has 'nvim-0.10' then
    ide.process.fatal 'minimum required Neovim version is 0.10'
    return
end

vim.headless = vim.list_contains(vim.api.nvim_get_vvar 'argv', '--headless') or #vim.api.nvim_list_uis() == 0

require 'options'

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

require 'init'

-- Post-load hook
vim.api.nvim_create_autocmd('User', {
    pattern = 'LazyVimStarted',
    callback = function()
        local opening_a_dir = vim.fn.argc() == 1 and vim.fs.dir_exists(vim.fn.argv(0) --[[@as string]])

        if opening_a_dir then
            require 'neo-tree'
        end
    end,
})
