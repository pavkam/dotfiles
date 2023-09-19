local astro_utils = require 'astronvim.utils'

return {
    remap = function(t, from, to, desc)
        t[to] = t[from]
        t[from] = nil

        if desc ~= nil and t[to] ~= nil then
            t[to].desc = desc
        end
    end,

    supmap = function(t, initial, secondary, desc)
        t[secondary] = t[initial]
        if desc ~= nil and t[secondary] ~= nil then
            t[secondary] = vim.tbl_extend('force', t[initial], { desc = desc .. ' (' .. initial .. ')' })
            t[initial].desc = desc
        end
    end,

    unmap = function(t, what)
        for _, k in ipairs(what) do
            t[k] = nil
        end
    end,

    is_plugin_available = astro_utils.is_available,
    get_icon = astro_utils.get_icon,
}
