M = {}

local group_index = 0

function M.auto_command(event, callback, pattern)
    group_name = "pavkam_" .. group_index
    group_index = group_index + 1

    local group = vim.api.nvim_create_augroup(group_name, { clear = true })

    vim.api.nvim_create_autocmd(event, {
        callback = callback,
        group = group,
        pattern = pattern,
    })
end

function M.plugin_available(plugin)
    local lazy_config_avail, lazy_config = pcall(require, "lazy.core.config")
    return lazy_config_avail and lazy_config.spec.plugins[plugin] ~= nil
end

return M
