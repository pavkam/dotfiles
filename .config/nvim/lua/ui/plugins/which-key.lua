local icons = require 'ui.icons'

return {
    'folke/which-key.nvim',
    cond = feature_level(1),
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
            ['<leader>b'] = { name = icons.UI.Buffers .. ' Buffers' },
            ['<leader>u'] = { name = icons.UI.UI .. ' Settings' },
            ['<leader>q'] = { name = icons.UI.Fix .. ' Quick-Fix' },
            ['<leader>f'] = { name = icons.UI.Search .. ' Search' },
            ['<leader>d'] = { name = icons.UI.Debugger .. ' Debugger' },
            ['<leader>x'] = { name = icons.UI.AI .. 'AI' },
            ['<leader>g'] = { name = icons.UI.Git .. ' Git' },
        },
    },
    config = function(_, opts)
        local wk = require 'which-key'
        wk.setup(opts)
        wk.register(opts.defaults)
    end,
}
