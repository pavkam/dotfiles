local icons = require 'ui.icons'

return {
    'echasnovski/mini.bufremove',
    cmd = { 'BufferRemove' },
    keys = {
        {
            '<leader>c',
            '<cmd>BufferRemove<cr>',
            desc = icons.UI.Close .. ' Close buffer',
        },
    },
    config = function(_, _)
        vim.api.nvim_create_user_command('BufferRemove', function()
            local should_remove = require('core.utils').confirm_saved(0, 'closing')
            if should_remove then
                require('mini.bufremove').delete(0, true)
            end
        end, { nargs = 0 })
    end,
}
