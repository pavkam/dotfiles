local astro_utils = require 'astronvim.utils'

local M = {
    map = astro_utils.set_mappings,
    list_insert_unique = astro_utils.list_insert_unique,
    is_plugin_available = astro_utils.is_available,
    get_icon = astro_utils.get_icon,
}

function M.remap(t, from, to, desc)
    t[to] = t[from]
    t[from] = nil

    if desc ~= nil and t[to] ~= nil then
        t[to].desc = desc
    end
end

function M.resupmap(t, from, primary, secondary, primary_desc, secondary_desc)
    M.remap(t, from, primary)
    M.supmap(t, primary, secondary, primary_desc, secondary_desc)
end

function M.supmap(t, primary, secondary, primary_desc, secondary_desc)
    if primary_desc ~= nil and t[initial] ~= nil then
        t[primary].desc = primary_desc
    end

    t[secondary] = t[primary]
    if t[secondary] ~= nil then
        if secondary_desc ~= nil then
            t[secondary] = vim.tbl_extend('force', t[secondary], { desc = secondary_desc })
        else
            t[secondary] = vim.tbl_extend('force', t[secondary], { desc = t[secondary].desc .. ' (' .. primary .. ')' })
        end
    end
end

function M.unmap(t, what)
    for _, k in ipairs(what) do
        t[k] = nil
    end
end

return M
