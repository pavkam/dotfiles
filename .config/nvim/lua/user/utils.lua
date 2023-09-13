local astro_utils = require 'astronvim.utils'

return {
    remap = function(t, from, to, desc)
        t[to] = t[from]
        t[from] = nil

        if desc ~= nil and t[to] ~= nil then
            t[to].desc = desc
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
