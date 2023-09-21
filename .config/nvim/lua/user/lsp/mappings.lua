local utils = require 'user.utils'

return function(mappings)
    local n = mappings.n
    local v = mappings.v

    utils.unmap(n, {
        '<leader>li',
        '<leader>lI',
        '<leader>lh',
        '<leader>lR',
        '<leader>lG',
        'gl',
    })

    utils.unmap(v, {
        '<leader>la',
        '<leader>lf',
    })

    utils.remap(n, '<leader>la', '<leader>ss', 'Code Actions')
    utils.remap(n, '<leader>lf', '<leader>sF', 'Format Buffer')
    utils.remap(n, '<leader>lr', '<leader>sR', 'Rename Symbol')
    utils.remap(n, '<leader>lD', '<leader>sM', 'Buffer Diagnostics')
    utils.remap(n, '<leader>ll', '<leader>sL', 'Refresh CodeLens')
    utils.remap(n, '<leader>lL', '<leader>sl', 'Run CodeLens')
    utils.remap(n, '<leader>ld', 'M')

    utils.supmap(n, 'gI', '<leader>si', 'Find Implementations')
    utils.supmap(n, 'gd', '<leader>sd', 'Find Definition')
    utils.supmap(n, 'gD', '<leader>sD', 'Find Declaration')
    utils.supmap(n, 'gy', '<leader>sT', 'Find Type Definition')
    utils.supmap(n, 'gr', '<leader>sr', 'Find References')
    utils.supmap(n, 'M', '<leader>sm', 'Line Diagnostics')

    if utils.is_plugin_available 'inc-rename.nvim' then
        require 'inc_rename'  -- force the plugin to load
        n['<leader>sR'] = {
            function()
                return ":IncRename " .. vim.fn.expand("<cword>")
            end,
            expr = true,
            desc = 'Rename symbol'
        }
    end

    n['<leader>s'] = { desc = utils.get_icon('ActiveLSP', 1, true) .. 'Source/Symbol' }

    return mappings
end
