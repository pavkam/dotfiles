local icons = require 'ui.icons'

---@class core.utils
local M = {}

math.randomseed(os.time())

--- Converts a value to a list
---@param value any # any value that will be converted to a list
---@return any[] # the listified version of the value
function M.to_list(value)
    if value == nil then
        return {}
    elseif vim.islist(value) then
        return value
    elseif type(value) == 'table' then
        local list = {}
        for _, item in ipairs(value) do
            table.insert(list, item)
        end

        return list
    else
        return { value }
    end
end

--- Inflates a list to a table
---@generic T: table
---@param list T[] # the list to inflate
---@param key_fn fun(value: T): string # the function to get the key from the value
---@return table<string, T> # the inflated table
function M.inflate_list(key_fn, list)
    assert(vim.islist(list) and type(key_fn) == 'function')

    ---@type table<string, table>
    local result = {}

    for _, value in ipairs(list) do
        local key = key_fn(value)
        result[key] = value
    end

    return result
end

--- Merges multiple tables into one
---@vararg table|nil # the tables to merge
---@return table # the merged table
function M.tbl_merge(...)
    local all = {}

    for _, a in ipairs { ... } do
        if a then
            table.insert(all, a)
        end
    end

    if #all == 0 then
        return {}
    elseif #all == 1 then
        return all[1]
    else
        return vim.tbl_deep_extend('force', unpack(all))
    end
end

--- Gets the value of an up-value of a function
---@param fn function # the function to get the up-value from
---@param name string # the name of the up-value to get
---@return any # the value of the up-value or nil if it does not exist
function M.get_up_value(fn, name)
    local i = 1
    while true do
        local n, v = debug.getupvalue(fn, i)
        if n == nil then
            break
        end

        if n == name then
            return v
        end

        i = i + 1
    end

    return nil
end

---@class (exact) core.utils.TraceBackEntry # a trace-back entry
---@field file string # the file of the entry
---@field line integer # the line of the entry
---@field fn_name string # the name of the function

--- Gets the trace-back of the current function
---@param level integer|nil # the level of the trace-back to get
---@return core.utils.TraceBackEntry[] # the trace-back entries
function M.get_trace_back(level)
    local trace = level and debug.traceback('', level) or debug.traceback()

    -- split trace by new-line into an array
    local lines = vim.split(trace, '\n', { plain = true, trimempty = true })

    ---@type core.utils.TraceBackEntry[]
    local result = {}
    for _, line in pairs(lines) do
        line = line:gsub('\t', '')
        local file, file_line, fn_name = line:match '([^:]+):(%d+): in (.+)'

        if fn_name == 'main chunk' then
            fn_name = 'module'
        else
            fn_name = fn_name and fn_name:match "function '(.+)'" or ''
            if fn_name == '' then
                fn_name = 'anonymous'
            end
        end

        if file and file_line then
            table.insert(result, {
                file = file,
                line = tonumber(file_line),
                fn_name = fn_name,
            })
        end
    end

    return result
end

---@type table<integer, uv_timer_t>
local deferred_buffer_timers = {}

require('core.events').on_event('BufDelete', function(evt)
    local timer = deferred_buffer_timers[evt.buf]
    if timer then
        timer:stop()
        deferred_buffer_timers[evt.buf] = nil
    end
end)

--- Defers a function call for buffer in LIFO mode. If the function is called again before the timeout, the
--- timer is reset.
---@param buffer integer|nil # the buffer to defer the function for or the current buffer if 0 or nil
---@param fn fun(buffer: integer) # the function to call
---@param timeout integer # the timeout in milliseconds
function M.defer_unique(buffer, fn, timeout)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local timer = deferred_buffer_timers[buffer]
    if not timer then
        timer = vim.uv.new_timer()
        deferred_buffer_timers[buffer] = timer
    else
        timer:stop()
    end

    local res = timer:start(
        timeout,
        0,
        vim.schedule_wrap(function()
            timer:stop()
            fn(buffer)
        end)
    )

    if res ~= 0 then
        M.error(string.format('Failed to start defer timer for buffer %d', buffer))
    end
end

---@alias core.utils.Target string|integer|nil # the target buffer or path or auto-detect

--- Expands a target of any command to a buffer and a path
---@param target core.utils.Target # the target to expand
---@return integer, string # the buffer and the path
function M.expand_target(target)
    if type(target) == 'number' or target == nil then
        target = target or vim.api.nvim_get_current_buf()
        return target, vim.api.nvim_buf_get_name(target)
    else
        local path = vim.fn.expand(target --[[@as string]])
        return vim.api.nvim_get_current_buf(), vim.uv.fs_realpath(vim.fn.expand(path)) or path
    end
end

--- Joins two paths
---@param part1 string # the first part of the path
---@param part2 string # the second part of the path
---@return string # the joined path
local function join_paths(part1, part2)
    part1 = part1:gsub('([^/])$', '%1/'):gsub('//', '/')
    part2 = part2:gsub('^/', '')

    return part1 .. part2
end

--- Joins multiple paths
---@vararg string|nil # the paths to join
---@return string|nil # the joined path or nil if none of the paths are valid
function M.join_paths(...)
    ---@type string|nil
    local acc
    for _, part in ipairs { ... } do
        if part ~= nil then
            if acc then
                acc = join_paths(acc, part)
            else
                acc = part
            end
        end
    end

    return acc
end

--- Checks if a file exists
---@param path string # the path to check
---@return boolean # true if the file exists, false otherwise
function M.file_exists(path)
    assert(type(path) == 'string')

    local stat = vim.uv.fs_stat(vim.fn.expand(path))
    return stat and stat.type == 'file' or false
end

--- Checks if files exist in a given directory and returns the first one that exists
---@param base_paths string|table<number, string|nil> # the list of base paths to check
---@param files string|table<number, string|nil> # the list of files to check
---@return string|nil # the first found file or nil if none exists
function M.first_found_file(base_paths, files)
    base_paths = M.to_list(base_paths)
    files = M.to_list(files)

    for _, path in ipairs(base_paths) do
        for _, file in ipairs(files) do
            local full = M.join_paths(path, file)
            if full and M.file_exists(full) then
                return M.join_paths(path, file)
            end
        end
    end

    return nil
end

---@type table<string, string>
local file_to_file_type = {}

--- Gets the file type of a file
---@param path string # the path to the file to get the type for
---@return string|nil # the file type or nil if the file type could not be determined
function M.file_type(path)
    assert(type(path) == 'string' and path ~= '')

    ---@type string|nil
    local file_type = file_to_file_type[path]
    if file_type then
        return file_type
    end

    file_type = vim.filetype.match { filename = path }
    if not file_type then
        for _, buf in ipairs(vim.fn.getbufinfo()) do
            if vim.fn.fnamemodify(buf.name, ':p') == path then
                return vim.filetype.match { buf = buf.bufnr }
            end
        end

        local bufn = vim.fn.bufadd(path)
        vim.fn.bufload(bufn)

        file_type = vim.filetype.match { buf = bufn }

        vim.api.nvim_buf_delete(bufn, { force = true })
    end

    file_to_file_type[path] = file_type

    return file_type
end

--- Simplifies a path by making it relative to another path and adding ellipsis
---@param prefix string # the prefix to make the path relative to
---@param path string # the path to simplify
---@return string # the simplified path
function M.format_relative_path(prefix, path)
    assert(type(prefix) == 'string')
    assert(type(path) == 'string')

    for _, p in ipairs { prefix, vim.env.HOME } do
        p = p:sub(-1) == '/' and p or p .. '/'

        if path:find(p, 1, true) == 1 then
            return icons.TUI.Ellipsis .. '/' .. path:sub(#p + 1)
        end
    end

    return path
end

---@class core.utils.PathComponents
---@field dir_name string # the directory name
---@field base_name string # the base name
---@field extension string # the extension
---@field compound_extension string # the compound extension

--- Splits a file path into its components
---@param path string # the path to split
---@return core.utils.PathComponents # the components of the path
function M.split_path(path)
    assert(type(path) == 'string' and path ~= '')

    local dir_name = vim.fn.fnamemodify(path, ':h')
    local base_name = vim.fn.fnamemodify(path, ':t')
    local extension = vim.fn.fnamemodify(path, ':e')
    local compound_extension = extension

    local parts = vim.split(base_name, '%.')
    if #parts > 2 then
        compound_extension = table.concat(vim.list_slice(parts, #parts - 1), '.')
    end

    return {
        dir_name = dir_name,
        base_name = base_name,
        extension = extension,
        compound_extension = compound_extension,
    }
end

--- Helper function that calculates folds
function M.fold_text()
    local ok = pcall(vim.treesitter.get_parser, vim.api.nvim_get_current_buf())
    ---@diagnostic disable-next-line: undefined-field
    local ret = ok and vim.treesitter.foldtext and vim.treesitter.foldtext() or nil
    if not ret then
        ret = {
            {
                vim.api.nvim_buf_get_lines(0, vim.v.lnum - 1, vim.v.lnum, false)[1],
                {},
            },
        }
    end

    table.insert(ret, { ' ' .. icons.TUI.Ellipsis })
    return ret
end

--- Confirms an operation that requires the buffer to be saved
---@param buffer integer|nil # the buffer to confirm for or the current buffer if 0 or nil
---@param reason string|nil # the reason for the confirmation
---@return boolean # true if the buffer was saved or false if the operation was cancelled
function M.confirm_saved(buffer, reason)
    buffer = buffer or vim.api.nvim_get_current_buf()
    if vim.bo[buffer].modified then
        local message = reason and 'Save changes to "%q" before %s?' or 'Save changes to "%q"?'
        local choice = vim.fn.confirm(
            string.format(message, vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buffer), ':t'), reason),
            '&Yes\n&No\n&Cancel'
        )

        if choice == 0 or choice == 3 then -- Cancel
            return false
        end

        if choice == 1 then -- Yes
            vim.api.nvim_buf_call(buffer, vim.cmd.write)
        end
    end

    return true
end

--- Gets the selected text from the current buffer in visual mode
---@return string # the selected text
function M.get_selected_text()
    if not M.is_visual_mode() then
        error 'Not in visual mode'
    end

    local old = vim.fn.getreg 'a'
    vim.cmd [[silent! normal! "aygv]]

    local original_selection = vim.fn.getreg 'a'
    vim.fn.setreg('a', old)

    local res, _ = original_selection:gsub('/', '\\/'):gsub('\n', '\\n')
    return res
end

--- Checks if a plugin is available
---@param name string # the name of the plugin
---@return boolean # true if the plugin is available, false otherwise
function M.has_plugin(name)
    assert(type(name) == 'string' and name ~= '')

    if package.loaded['lazy'] then
        return require('lazy.core.config').spec.plugins[name] ~= nil
    end

    return false
end

--- Checks if a mode is visual
---@param mode string|nil # the mode to check or the current mode if nil
---@return boolean # true if the mode is visual, false otherwise
function M.is_visual_mode(mode)
    mode = mode or vim.api.nvim_get_mode().mode

    return mode == 'v' or mode == 'V' or mode == ''
end

--- Runs a function with the current visual selection
---@param buffer integer|nil # the buffer to run the function for or the current buffer if 0 or nil
---@param callback fun(restore_callback: fun(command?: string)) # the callback to call with the selection
function M.run_with_visual_selection(buffer, callback)
    assert(type(callback) == 'function')

    if not M.is_visual_mode() then
        error 'Not in visual mode'
    end

    buffer = buffer or vim.api.nvim_get_current_buf()
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes([[<esc>]], true, false, true), 'n', false)

    vim.schedule(function()
        local sel_start = vim.api.nvim_buf_get_mark(buffer, '<')
        local sel_end = vim.api.nvim_buf_get_mark(buffer, '>')

        local restore_callback = function(command)
            vim.api.nvim_buf_set_mark(buffer, '<', sel_start[1], sel_start[2], {})
            vim.api.nvim_buf_set_mark(buffer, '>', sel_end[1], sel_end[2], {})

            vim.api.nvim_feedkeys([[gv]], 'n', false)

            if command then
                vim.api.nvim_feedkeys(
                    vim.api.nvim_replace_termcodes(string.format(':%s<cr>', command), true, false, true),
                    'n',
                    false
                )
            end
        end

        callback(restore_callback)
    end)
end

--- Refreshes the UI
function M.refresh_ui()
    vim.cmd.resize()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd 'tabdo wincmd ='
    vim.cmd('tabnext ' .. current_tab)
    vim.cmd 'redraw!'
end

---@type string
local uuid_template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'

function M.uuid()
    ---@param c string
    local function subs(c)
        local v = (((c == 'x') and math.random(0, 15)) or math.random(8, 11))
        return string.format('%x', v)
    end

    return uuid_template:gsub('[xy]', subs)
end

--- Gets the timezone offset for a given timestamp
---@param timestamp integer # the timestamp to get the offset for
---@return integer # the timezone offset
function M.get_timezone_offset(timestamp)
    assert(type(timestamp) == 'number')

    local utc_date = os.date('!*t', timestamp)
    local local_date = os.date('*t', timestamp)

    local_date.isdst = false

    local diff = os.difftime(os.time(local_date --[[@as osdateparam]]), os.time(utc_date --[[@as osdateparam]]))
    local h, m = math.modf(diff / 3600)

    return 100 * h + 60 * m
end

local undo_command = vim.api.nvim_replace_termcodes('<c-G>u', true, true, true)

--- Creates an undo point if in insert mode
function M.create_undo_point()
    assert(vim.api.nvim_get_mode().mode == 'i')

    vim.api.nvim_feedkeys(undo_command, 'n', false)
end

return M
