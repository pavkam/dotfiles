local icons = require 'utils.icons'

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
            ['<leader>b'] = { name = icons.UI.Buffers .. ' Buffers' },
            ['<leader>u'] = { name = icons.UI.UI .. ' Settings' },
            ['<leader>q'] = { name = icons.UI.Fix .. ' Quick-Fix' },
            ['<leader>f'] = { name = icons.UI.Search .. ' Search' },
            ['<leader>?'] = { name = icons.UI.Help .. ' Help' },
            ['<leader>d'] = { name = icons.UI.Debugger .. ' Debugger' },
            ['<leader>s'] = { name = icons.UI.LSP .. ' Source' },
        },
    },
    config = function(_, opts)
        local wk = require 'which-key'
        wk.setup(opts)
        wk.register(opts.defaults)
    end,
}
