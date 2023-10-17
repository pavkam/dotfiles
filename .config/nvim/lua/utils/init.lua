local M = {}

-- general utils

local function stringify(value)
    if value == nil then
        return "nil"
    elseif type(value) == "string" then
        return value
    elseif type(value) == "table" then
        return vim.inspect(value)
    elseif type(value) == "function" then
        return stringify(value())
    else
        return tostring(value)
    end
end

function M.to_list(value)
    if value == nil then
        return {}
    elseif vim.tbl_islist(value) then
        return value
    elseif type(value) == "table" then
        local list = {}
        for _, item in ipairs(value) do
            table.insert(list, item)
        end

        return list
    else
        return { value }
    end
end

function M.list_insert_unique(list, values)
    list = M.to_list(list)
    values = M.to_list(values)

    local added = {}
    vim.tbl_map(function(v) added[v] = true end, list)

    for _, val in ipairs(values) do
        if not added[val] then
            table.insert(list, val)
            added[val] = true
        end
    end

    return list
end

function M.tbl_join(items, separator)
    if not vim.tbl_islist(items) then
        return stringify(items)
    end

    local result = ""

    for _, item in ipairs(items) do
        if #result > 0 and separator ~= nil then
            result = result .. separator
        end

        result = result .. stringify(item)
    end

    return result
end

function M.tbl_copy(table)
    return vim.tbl_extend("force", {}, table)
end

function M.tbl_merge(...)
    local all = {}

    for _, a in ipairs({...}) do
        if a then
            table.insert(all, a)
        end
    end

    if #all == 0 then
        return {}
    elseif #all == 1 then
        return all[1]
    else
       return vim.tbl_deep_extend("force", unpack(all))
    end
end

function M.stringify(...)
    local args = { ... }
    if #args == 1 then
        return stringify(...)
    else
        return M.tbl_join(args, " ")
    end
end

-- vim utils

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

function M.debounce(ms, fn)
    local timer = vim.loop.new_timer()

    return function(...)
        local argv = { ... }

        timer:start(ms, 0, function()
            timer:stop()
            vim.schedule_wrap(fn)(unpack(argv))
        end)
    end
end

function M.event_memoized(event, pattern, ...)
    local funcs = {...}
    assert(#funcs > 0, "event_momoized: at least one function must be provided")

    -- create memoized functions using a local cache
    local cache = {}
    local out_functions = {}
    for i, func in ipairs(funcs) do
        assert(type(func) == "function", "event_momoized: all arguments must be functions")
        table.insert(out_functions, function(...)
            if cache[i] == nil then
                print("evaluating")
                cache[i] = func(...)
            end

            return cache[i]
        end)
    end

    M.auto_command(
        event,
        function()
            print("clearing!")
            -- clear the cached value so that they will be reevaluated again when
            -- asked for.
            for i, _ in ipairs(cache) do
                cache[i] = nil
            end
        end,
        pattern
    )

    return unpack(out_functions)
end

-- notification utils

function M.notify(msg, type, opts)
    vim.schedule(
        function()
            vim.notify(M.stringify(msg), type, M.tbl_merge({ title = "NeoVim" }, opts))
        end
    )
end

function M.info(msg)
    M.notify(msg, vim.log.levels.INFO)
end

function M.warn(msg)
    M.notify(msg, vim.log.levels.WARN)
end

function M.error(msg)
    M.notify(msg, vim.log.levels.ERROR)
end

-- terminal and buffer utils

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

function M.expand_target(target)
    if type(target) == "function" then
        target = target()
    end

    if type(target) == "number" then
        return target, vim.api.nvim_buf_get_name(target)
    else
        local path = M.stringify(target)
        return vim.api.nvim_get_current_buf(), path ~= "" and vim.loop.fs_realpath(path) or nil
    end
end

-- file utils

local function join_paths(part1, part2)
    part1 = part1:gsub("([^/])$", "%1/"):gsub("//", "/")
    part2 = part2:gsub("^/", "")

    return part1 .. part2
end

function M.join_paths(...)
    local parts = {...}
    if #parts == 0 then
        return nil
    elseif #parts == 1 then
        return parts[1]
    end

    local acc = M.stringify(table.remove(parts, 1))
    for _, part in ipairs(parts) do
        acc = join_paths(acc, M.stringify(part))
    end

    return acc
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
