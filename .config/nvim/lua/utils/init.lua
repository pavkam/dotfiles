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

function M.list_insert_unique(lst, vals)
    if not lst then lst = {} end

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

local terminals = {}

function M.float_term(cmd, opts)
    opts = vim.tbl_deep_extend("force", {
        ft = "lazyterm",
        size = { width = 0.9, height = 0.9 },
    }, opts or {}, { persistent = true })

  local termkey = vim.inspect({
        cmd = cmd or "shell",
        cwd = opts.cwd,
        env = opts.env,
        count = vim.v.count1
    })

    if terminals[termkey] and terminals[termkey]:buf_valid() then
        terminals[termkey]:toggle()
    else
        terminals[termkey] = require("lazy.util").float_term(cmd, opts)

        local buf = terminals[termkey].buf
        vim.b[buf].lazyterm_cmd = cmd

        vim.api.nvim_create_autocmd(
            "BufEnter",
            {
                buffer = buf,
                callback = function()
                    vim.cmd.startinsert()
                end
            }
        )
    end

    return terminals[termkey]
end

function M.tbl_join(items, separator)
    if not vim.tbl_islist(items) then
        return tostring(items)
    end

    local result = ""

    for _, item in ipairs(items) do
        result = result .. tostring(item)
        if #result > 0 and separator ~= nil then
            result = result .. separator
        end
    end

    return result
end

return M