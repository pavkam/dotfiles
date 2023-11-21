return {
    'echasnovski/mini.bufremove',
    keys = {
        {
            '<leader>bd',
            function()
                require('utils').confirm_saved(nil, 'closing')
            end,
            desc = 'Delete buffer',
        },
        {
            '<leader>bD',
            function()
                require('mini.bufremove').delete(0, true)
            end,
            desc = 'Delete buffer (force)',
        },
    },
}
