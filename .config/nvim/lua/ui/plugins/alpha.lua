return {
    'goolord/alpha-nvim',
    -- URGENT: alpha is failing
    cond = false,
    dependencies = {
        'nvim-tree/nvim-web-devicons',
    },
    event = 'VimEnter',
    opts = function()
        local icons = require 'ui.icons'

        local dashboard = require 'alpha.themes.dashboard'
        local logo = [[
,-.       _,---._ __  / \
/  )    .-'       `./ /   \
(  (   ,'            `/    /|
\  `-"             \'\   / |
`.              ,  \ \ /  |
/`.          ,'-`----Y   |
(            ;        |   '
|  ,-.    ,-'         |  /
|  | (   |            | /
)  |  \  `.___________|/
`--'   `--'
        ]]

        dashboard.section.header.val = vim.split(logo, '\n')
        dashboard.section.buttons.val = {
            dashboard.button('e', icons.UI.Explorer .. ' File Explorer', ':Neotree toggle <CR>'),
            dashboard.button('f', icons.UI.Search .. '  Find Files', ':Telescope find_files <CR>'),
            dashboard.button('b', icons.Files.Normal .. '  Used Files', ':Files<CR>'),
            dashboard.button('l', icons.UI.Sleep .. ' Lazy', ':Lazy<CR>'),
            dashboard.button('q', icons.UI.Quit .. ' Quit', ':qa<CR>'),
        }

        for _, button in ipairs(dashboard.section.buttons.val) do
            button.opts.hl = 'AlphaButtons'
            button.opts.hl_shortcut = 'AlphaShortcut'
        end

        dashboard.section.header.opts.hl = 'AlphaHeader'
        dashboard.section.buttons.opts.hl = 'AlphaButtons'
        dashboard.section.footer.opts.hl = 'AlphaFooter'
        dashboard.opts.layout[1].val = 8

        return dashboard
    end,
    config = function(_, dashboard)
        local events = require 'core.events'
        local icons = require 'ui.icons'

        if vim.o.filetype == 'lazy' then
            vim.cmd.close()

            events.on_user_event('AlphaReady', function()
                require('lazy').show()
            end)
        end

        require('alpha').setup(dashboard.opts)

        events.on_user_event('LazyVimStarted', function()
            local stats = require('lazy').stats()
            local ms = (math.floor(stats.startuptime * 100 + 0.5) / 100)

            dashboard.section.footer.val =
                icons.iconify(icons.UI.Speed, string.format('Neovim loaded %d plugins in %d ms', stats.count, ms))

            pcall(vim.cmd.AlphaRedraw)
        end)
    end,
}
