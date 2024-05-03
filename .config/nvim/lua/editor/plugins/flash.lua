return {
    'folke/flash.nvim',
    opts = {},
    keys = {
        {
            '<M-/>',
            mode = { 'n', 'x', 'o' },
            function()
                require('flash').jump()
            end,
            desc = 'Flash',
        },
        {
            '<M-?>',
            mode = { 'n', 'o', 'x' },
            function()
                require('flash').treesitter()
            end,
            desc = 'Flash (Treesitter)',
        },
    },
}
