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

--- Insert one or more values into a list like table and maintain that you do not insert non-unique values (THIS MODIFIES `lst`)
---@param lst any[]|nil The list like table that you want to insert into
---@param vals any|any[] Either a list like table of values to be inserted or a single value to be inserted
---@return any[] # The modified list like table
function M.list_insert_unique(lst, vals)
    if not lst then lst = {} end
    assert(vim.tbl_islist(lst), "Provided table is not a list like table")
    if not vim.tbl_islist(vals) then vals = { vals } end
    local added = {}
    vim.tbl_map(function(v) added[v] = true end, lst)
    for _, val in ipairs(vals) do
        if not added[val] then
        table.insert(lst, val)
        added[val] = true
        end
    end
    return lst
end

return M
