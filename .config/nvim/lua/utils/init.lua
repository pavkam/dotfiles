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

function M.on_event(event, callback, pattern)
    group_name = "pavkam_" .. group_index
    group_index = group_index + 1

    local group = vim.api.nvim_create_augroup(group_name, { clear = true })

    vim.api.nvim_create_autocmd(event, {
        callback = callback,
        group = group,
        pattern = pattern,
    })
end

function M.on_user_event(event, callback)
    M.on_event("User", function(evt) callback(evt.match, evt) end, event)
end

function M.debounce(ms, callback)
    assert(type(ms) == "number" and ms > 0)
    assert(type(callback) == "function")

    local timer = vim.loop.new_timer()
    local wrapped = vim.schedule_wrap(callback)

    timer:start(ms, 0, function()
        timer:stop()
        wrapped()
    end)
end

function M.event_memoized(event, pattern, ...)
    local funcs = {...}
    assert(#funcs > 0)

    -- create memoized functions using a local cache
    local cache = {}
    local out_functions = {}
    for i, func in ipairs(funcs) do
        assert(type(func) == "function")
        table.insert(out_functions, function() return cache[i] end)
    end

    M.on_event(
        event,
        function(evt)
            for i, func in ipairs(funcs) do
                cache[i] = func(evt.buf)
            end
        end,
        pattern
    )

    return unpack(out_functions)
end

function M.user_event_memoized(event, ...)
    return M.event_memoized("User", event, ...)
end

function M.trigger_user_event(event, data)
    vim.api.nvim_exec_autocmds("User", { pattern = event, modeline = false, data = data })
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

function M.get_listed_buffers()
    return vim.tbl_filter(function(b)
        return (
            vim.api.nvim_buf_is_valid(b) and
            vim.api.nvim_buf_is_loaded(b) and
            true --vim.b[b].buflisted
        )
    end, vim.api.nvim_list_bufs())
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

function M.cmd(cmd, show_error)
    cmd = M.to_list(cmd)

    if vim.fn.has "win32" == 1 then
        cmd = vim.list_extend({ "cmd.exe", "/C" }, cmd)
    end

    local result = vim.fn.system(cmd)
    local success = vim.api.nvim_get_vvar "shell_error" == 0

    if not success and (show_error == nil or show_error) then
        M.error(string.format("Error running command *%s*\nError message:\n**%s**", M.tbl_join(cmd, " "), result))
    end

    return success and result:gsub("[\27\155][][()#;?%d]*[A-PRZcf-ntqry=><~]", "") or nil
end

function M.file_is_under_git(file_name)
    return M.cmd({ "git", "-C", vim.fn.fnamemodify(file_name, ":p:h"), "rev-parse" }, false) ~= nil
end

return M
