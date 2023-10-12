local M = {}

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

function M.join_paths(part1, part2)
    part1 = part1:gsub("([^/])$", "%1/"):gsub("//", "/")
    part2 = part2:gsub("^/", "")

    return part1 .. part2
end

function M.file_exists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    else
        return false
    end
end

function M.any_file_exists(base_path, files)
    for _, file in ipairs(files) do
        if M.file_exists(M.join_paths(base_path, file)) then
            return file
        end
    end

    return nil
end

function M.read_text_file(path)
    local file = io.open(path, "rb")
    if not file then
        return nil
    end

    local content = file:read "*a"
    file:close()

    return content
end

return M
