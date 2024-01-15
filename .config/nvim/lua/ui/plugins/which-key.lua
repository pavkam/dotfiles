local icons = require 'ui.icons'

return {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    opts = {
        plugins = { spelling = true },
        icons = {
            group = '',
        },
        defaults = {
            mode = { 'n', 'v' },
            ['g'] = { name = icons.UI.Next .. ' Go-to' },
            [']'] = { name = icons.UI.Next .. ' Next' },
            ['['] = { name = icons.UI.Prev .. ' Previous' },
            ['<leader>u'] = { name = icons.UI.UI .. ' UX' },
            ['<leader>q'] = { name = icons.UI.Fix .. ' Quick-Fix' },
            ['<leader>d'] = { name = icons.UI.Debugger .. ' Debugger' },
        },
    },
    config = function(_, opts)
        local wk = require 'which-key'
        wk.setup(opts)
        wk.register(opts.defaults)
    end,
}
