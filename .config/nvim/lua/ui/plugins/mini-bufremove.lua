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
        local utils = require 'core.utils'

        utils.register_command('BufferRemove', function()
            local should_remove = require('core.utils').confirm_saved(0, 'closing')
            if should_remove then
                local buffer = vim.api.nvim_get_current_buf()

                require('mini.bufremove').delete(buffer, true)

                -- Special code to manage alpha
                if utils.has_plugin 'alpha-nvim' then
                    local buffers = utils.get_listed_buffers()

                    if #buffers == 1 and buffers[1] == buffer then
                        require('alpha').start()
                        vim.schedule(function()
                            for _, b in ipairs(utils.get_listed_buffers()) do
                                vim.api.nvim_buf_delete(b, { force = true })
                            end
                        end)
                    end
                end
            end
        end, { desc = 'Close buffer' })
    end,
}
