return {
    'andrewferrier/debugprint.nvim',
    cond = feature_level(3),
    keys = {
        {
            '<leader>Dp',
            function()
                return require('debugprint').debugprint()
            end,
            mode = 'n',
            expr = true,
            desc = 'Debug print (below)',
        },
        {
            '<leader>DP',
            function()
                return require('debugprint').debugprint { above = true }
            end,
            mode = 'n',
            expr = true,
            desc = 'Debug print (above)',
        },
        {
            '<leader>Dv',
            function()
                return require('debugprint').debugprint { variable = true }
            end,
            mode = { 'v', 'n' },
            expr = true,
            desc = 'Debug print variable (below)',
        },
        {
            '<leader>DV',
            function()
                return require('debugprint').debugprint { variable = true, above = true }
            end,
            mode = { 'v', 'n' },
            expr = true,
            desc = 'Debug print variable (above)',
        },
        {
            '<leader>Dd',
            function()
                require('debugprint').deleteprints()
            end,
            mode = { 'n' },
            desc = 'Remove all debug prints in buffer',
        },
    },
    dependencies = {
        'nvim-treesitter/nvim-treesitter',
    },
    opts = {
        create_keymaps = false,
        create_commands = false,
    },
}
