-- MAYBE: jump to buf (https://github.com/catgoose/templ-goto-definition/blob/main/lua/templ-goto-definition/init.lua)
--
-- LOW: Evaluate difftastic
-- LOW: Evaluate grug-far
--      (https://www.reddit.com/r/neovim/comments/1f4al0o/grugfarnvim_update_multiline_input_and_telescope/)
-- LOW: integrate with "cSpell.words" in .vscode/settings.json
-- LOW: rework the shell module or drop it in favor or built-in nvim code.
-- LOW: Maybe find a way to configure semantic tokens to avoid comments and string literals:
--      https://gist.github.com/swarn/fb37d9eefe1bc616c2a7e476c0bc0316#controlling-when-highlights-are-applied.
-- LOW: https://www.reddit.com/media?url=https%3A%2F%2Fpreview.redd.it%2Fabsolutely-disgusting-i-always-felt-like-classic-windows-v0-nhzc86yzuzwd1.png%3Fwidth%3D1487%26format%3Dpng%26auto%3Dwebp%26s%3Dfe530c3e87b14e551c692573014f9eea6a8cf0e1
-- LOW: disable 'u' and 'U' in visual mode, just annoying
-- LOW: https://github.com/ecosse3/nvim/blob/master/lua/plugins/todo-comments.lua
-- LOW: https://github.com/ecosse3/nvim/blob/master/lua/plugins/spider.lua
-- LOW: https://www.reddit.com/r/neovim/comments/1gpe3zk/plugins_for_displaying_type_interface_information/
-- LOW: https://github.com/benlubas/cmp2lsp/blob/main/lua/cmp2lsp/init.lua
-- LOW: https://github.com/daliusd/ghlite.nvim
-- LOW: package-info is crap, make a smaller one just to show versions and if module is deprecated.
-- TODO: improve the mouse right-click: https://github.com/neovim/neovim/commit/76aa3e52be7a5a8b53b3775981c35313284230ac
-- TODO: Use copilot to describe vim commands with suggestions:
--      https://github.com/oflisback/describe-command.nvim/blob/main/lua/describe-command/commands.lua
--
-- TODO: ability to select the root of the project
-- TODO: typos lsp has issues when disabled. Not sure how to deal with it at the moment.
-- TODO: expose the group for the mapping of keys (refactor keys module)

-- URGENT: https://github.com/tjdevries/lazy-require.nvim/blob/master/lua/lazy-require.lua
-- URGENT: https://github.com/folke/snacks.nvim/tree/main
require 'init'

if not ide.process.at_least_version(0, 10) then
    return ide.process.fatal 'minimum required Neovim version is 0.10'
end

if not ide.process.tool_exists 'git' then
    return ide.process.fatal 'git required'
end

require 'options' -- TODO: this must go

-- Setup the Lazy plugin manager
ide.plugin.require_online('https://github.com/folke/lazy.nvim.git', ide.fs.join_paths('lazy', 'lazy.nvim'))

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

require 'init2'

-- TODO: not working
-- Post-load hook
vim.api.nvim_create_autocmd('User', {
    pattern = 'LazyVimStarted',
    callback = function()
        local opening_a_dir = vim.fn.argc() == 1 and ide.fs.directory_exists(vim.fn.argv(0) --[[@as string]])

        if opening_a_dir then
            require 'neo-tree'
        end
    end,
})
