local icons = require 'ui.icons'

return {
    'echasnovski/mini.bufremove',
    keys = {
        {
            '<leader>c',
            function()
                local should_remove = require('core.utils').confirm_saved(0, 'closing')
                if should_remove then
                    require('mini.bufremove').delete(0, true)
                end
            end,
            desc = icons.UI.Close .. ' Close buffer',
        },
    },
}
