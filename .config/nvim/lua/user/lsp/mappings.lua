local utils = require 'astronvim.utils'
local is_available = utils.is_available
local get_icon = utils.get_icon

return function(mappings)
    local n = mappings.n
    local v = mappings.v

    local remap = function(t, from, to, desc)
        t[to] = t[from]
        t[from] = nil

        if desc ~= nil and t[to] ~= nil then
            t[to].desc = desc
        end
    end

    local unmap = function(t, what)
        for _, k in ipairs(what) do
            t[k] = nil
        end
    end

    unmap(n, {
        '<leader>li',
        '<leader>lI',
        '<leader>lh',
        'gr',
        'gl',
    })

    unmap(v, {
        '<leader>la',
        '<leader>lf',
    })

    remap(n, '<leader>la', '<leader>s.')
    remap(n, '<leader>lf', '<leader>sF')
    remap(n, '<leader>lR', '<leader>sr')
    remap(n, '<leader>lr', '<leader>sR')
    remap(n, '<leader>lD', '<leader>sM')
    remap(n, '<leader>ld', '<leader>sm')
    remap(n, 'gI', '<leader>si')
    remap(n, 'gd', '<leader>sd')
    remap(n, 'gD', '<leader>sD')
    remap(n, 'gy', '<leader>st')
    remap(n, '<leader>lG', '<leader>fS', 'Find symbols in workspace')

    if is_available 'inc-rename.nvim' then
        require 'inc_rename'  -- force the plugin to load
        n['<leader>sR'] = {
            function()
                return ":IncRename " .. vim.fn.expand("<cword>")
            end,
            expr = true,
            desc = 'Rename symbol'
        }
    end

    n['<leader>s'] = { desc = get_icon('ActiveLSP', 1, true) .. 'Source/Symbol' }

    return mappings
end
