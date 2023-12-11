return {
    'echasnovski/mini.bufremove',
    cond = feature_level(2),
    keys = {
        {
            '<leader>bd',
            function()
                local should_remove = require('utils').confirm_saved(0, 'closing')
                if should_remove then
                    require('mini.bufremove').delete(0, true)
                end
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
