local utils = require 'user.utils'

return function(mappings)
    local n = mappings.n
    local v = mappings.v

    utils.unmap(n, {
        '<leader>li',
        '<leader>lI',
        '<leader>lh',
        'gr',
        'gl',
        'gx',
    })

    utils.unmap(v, {
        '<leader>la',
        '<leader>lf',
    })

    utils.remap(n, '<leader>la', '<leader>s.')
    utils.remap(n, '<leader>lf', '<leader>sF')
    utils.remap(n, '<leader>lR', '<leader>sr')
    utils.remap(n, '<leader>lr', '<leader>sR')
    utils.remap(n, '<leader>lD', '<leader>sM')
    utils.remap(n, '<leader>ld', '<leader>sm')
    utils.remap(n, '<leader>ll', '<leader>sL')
    utils.remap(n, '<leader>lL', '<leader>sl')
    utils.remap(n, 'gI', '<leader>si')
    utils.remap(n, 'gd', '<leader>sd')
    utils.remap(n, 'gD', '<leader>sD')
    utils.remap(n, 'gy', '<leader>st')
    utils.remap(n, '<leader>lG', '<leader>fS', 'Find symbols in workspace')

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
