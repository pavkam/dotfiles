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

    utils.remap(n, '<leader>la', '<leader>ss', 'Code actions')
    utils.remap(n, '<leader>lf', '<leader>sF', 'Format buffer')
    utils.remap(n, '<leader>lr', '<leader>sR', 'Rename symbol')
    utils.remap(n, '<leader>lD', '<leader>sM', 'Buffer diagnostics')
    utils.remap(n, '<leader>ll', '<leader>sL', 'Refresh CodeLens')
    utils.remap(n, '<leader>lL', '<leader>sl', 'Run CodeLens')
    utils.remap(n, '<leader>ld', 'M', 'Line diagnostics')

    utils.supmap(n, 'gI', '<leader>si', 'Find implementations')
    utils.supmap(n, 'gd', '<leader>sd', 'Find definition')
    utils.supmap(n, 'gD', '<leader>sD', 'Find declaration')
    utils.supmap(n, 'gy', '<leader>sT', 'Find type definition')
    utils.supmap(n, 'gr', '<leader>sr', 'Find references')
    utils.supmap(n, 'M', '<leader>sm', 'Line diagnostics')

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
