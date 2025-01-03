return {
    'folke/flash.nvim',
    cond = not ide.process.is_headless,
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
            '<C-_>',
            mode = { 'n', 'o', 'x' },
            function()
                require('flash').treesitter()
            end,
            desc = 'Flash (Treesitter)',
        },
    },
}
