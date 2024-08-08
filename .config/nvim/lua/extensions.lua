--- Global function to quit the current process
function _G.quit()
    vim.api.nvim_command 'cq1'
end

--- Global debug function to help me debug (duh)
---@vararg any anything to debug
function _G.dbg(...)
    local objects = {}
    for _, v in pairs { ... } do
        ---@type string
        local val = 'nil'

        if type(v) == 'string' then
            val = v
        elseif type(v) == 'number' or type(v) == 'boolean' then
            val = tostring(v)
        elseif type(v) == 'table' then
            val = vim.inspect(v)
        end

        table.insert(objects, val)
    end

    local message = table.concat(objects, '\n')

    vim.notify(message)

    return ...
end

--- Prints the call stack if a condition is met
---@param cond any # the condition to print the call stack
---@vararg any # anything to print
function _G.who(cond, ...)
    if cond == nil or cond then
        dbg(debug.traceback(nil, 2), ...)
    end
end

--- Global function to log a message as an error and quit
---@param message string the message to log
function _G.fatal(message)
    assert(type(message) == 'string')

    error(string.format('fatal error has occurred: %s', message))
    error 'press any key to quit the process'

    vim.fn.getchar()

    vim.api.nvim_command 'cq1'
end

--- Converts a value to a list
---@param value any # any value that will be converted to a list
---@return any[] # the listified version of the value
function vim.to_list(value)
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
function vim.inflate_list(key_fn, list)
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
function vim.tbl_merge(...)
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
function _G.get_up_value(fn, name)
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

---@class (exact) vim.TraceBackEntry # a trace-back entry
---@field file string # the file of the entry
---@field line integer # the line of the entry
---@field fn_name string # the name of the function

--- Gets the trace-back of the current function
---@param level integer|nil # the level of the trace-back to get
---@return vim.TraceBackEntry[] # the trace-back entries
function _G.get_trace_back(level)
    local trace = level and debug.traceback('', level) or debug.traceback()

    -- split trace by new-line into an array
    local lines = vim.split(trace, '\n', { plain = true, trimempty = true })

    ---@type vim.TraceBackEntry[]
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

math.randomseed(os.time())

---@type string
local uuid_template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'

--- Generates a new UUID
---@return string # the generated UUID
function vim.fn.uuid()
    ---@param c string
    local function subs(c)
        local v = (((c == 'x') and math.random(0, 15)) or math.random(8, 11))
        return string.format('%x', v)
    end

    local res = uuid_template:gsub('[xy]', subs)
    return res
end

--- Gets the timezone offset for a given timestamp
---@param timestamp integer # the timestamp to get the offset for
---@return integer # the timezone offset
function vim.fn.timezone_offset(timestamp)
    assert(type(timestamp) == 'number')

    local utc_date = os.date('!*t', timestamp)
    local local_date = os.date('*t', timestamp)

    local_date.isdst = false

    local diff = os.difftime(os.time(local_date --[[@as osdateparam]]), os.time(utc_date --[[@as osdateparam]]))
    local h, m = math.modf(diff / 3600)

    return 100 * h + 60 * m
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
function vim.fs.join_paths(...)
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

--- URGENT: can this be simplified?
--- Checks if a file exists
---@param path string # the path to check
---@return boolean # true if the file exists, false otherwise
function vim.fs.file_exists(path)
    assert(type(path) == 'string')

    local stat = vim.uv.fs_stat(vim.fn.expand(path))
    return stat and stat.type == 'file' or false
end

--- Checks if files exist in a given directory and returns the first one that exists
---@param base_paths string|table<number, string|nil> # the list of base paths to check
---@param files string|table<number, string|nil> # the list of files to check
---@return string|nil # the first found file or nil if none exists
function vim.fs.first_found_file(base_paths, files)
    base_paths = vim.to_list(base_paths)
    files = vim.to_list(files)

    for _, path in ipairs(base_paths) do
        for _, file in ipairs(files) do
            local full = vim.fs.join_paths(path, file)
            if full and vim.fs.file_exists(full) then
                return vim.fs.join_paths(path, file)
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
function vim.fs.file_type(path)
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
function vim.fs.format_relative_path(prefix, path)
    assert(type(prefix) == 'string')
    assert(type(path) == 'string')

    for _, p in ipairs { prefix, vim.env.HOME } do
        p = p:sub(-1) == '/' and p or p .. '/'

        if path:find(p, 1, true) == 1 then
            return '…/' .. path:sub(#p + 1)
        end
    end

    return path
end

---@class (exact) vim.PathComponents # The components of a path
---@field dir_name string # the directory name
---@field base_name string # the base name
---@field extension string # the extension
---@field compound_extension string # the compound extension

--- Splits a file path into its components
---@param path string # the path to split
---@return vim.PathComponents # the components of the path
function vim.fs.split_path(path)
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

--- Checks if a mode is visual
---@param mode string|nil # the mode to check or the current mode if nil
---@return boolean # true if the mode is visual, false otherwise
function vim.fn.is_visual_mode(mode)
    mode = mode or vim.api.nvim_get_mode().mode

    return mode == 'v' or mode == 'V' or mode == ''
end

--- Gets the selected text from the current buffer in visual mode
---@return string # the selected text
function vim.fn.visual_selected_text()
    if not vim.fn.is_visual_mode() then
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
function vim.has_plugin(name)
    assert(type(name) == 'string' and name ~= '')

    if package.loaded['lazy'] then
        return require('lazy.core.config').spec.plugins[name] ~= nil
    end

    return false
end

---Converts a value to a string
---@param value any # any value that will be converted to a string
---@return string|nil # the stringified version of the value
function vim.stringify(value)
    if value == nil then
        return nil
    elseif type(value) == 'string' then
        return value
    elseif vim.islist(value) then
        return table.concat(value, ', ')
    elseif type(value) == 'table' then
        return vim.inspect(value)
    elseif type(value) == 'function' then
        return vim.stringify(value())
    else
        return tostring(value)
    end
end

---@class (exact) vim.NotifyOpts # the options to pass to the notification
---@field prefix_icon string|nil # the icon to prefix the message with
---@field suffix_icon string|nil # the icon to suffix the message with
---@field title string|nil # the title of the notification

--- Shows a notification
---@param msg any # the message to show
---@param level integer # the level of the notification
---@param opts vim.NotifyOpts|nil # the options to pass to the notification
local function notify(msg, level, opts)
    msg = vim.stringify(msg) or ''

    if opts and opts.prefix_icon then
        msg = opts.prefix_icon .. ' ' .. msg
    end

    if opts and opts.suffix_icon then
        msg = msg .. ' ' .. opts.suffix_icon
    end

    local title = opts and opts.title or 'NeoVim'

    if vim.v.exiting ~= vim.NIL or vim.v.dying > 0 then
        if level == vim.log.levels.ERROR then
            vim.api.nvim_err_writeln(string.format('[%s] %s', title, msg))
        else
            vim.api.nvim_out_write(string.format('[%s] %s\n', title, msg))
        end

        return
    end

    if vim.in_fast_event() then
        vim.notify(msg, level, { title = title })
        return
    end

    vim.schedule(function()
        vim.notify(msg, level, { title = title })
    end)
end

--- Shows a notification with the INFO type
---@param msg any # the message to show
---@param opts vim.NotifyOpts|nil # the options to pass to the notification
function vim.info(msg, opts)
    notify(msg, vim.log.levels.INFO, opts)
end

--- Shows a notification with the WARN type
---@param msg any # the message to show
---@param opts vim.NotifyOpts|nil # the options to pass to the notification
function vim.warn(msg, opts)
    notify(msg, vim.log.levels.WARN, opts)
end

--- Shows a notification with the ERROR type
---@param msg any # the message to show
---@param opts vim.NotifyOpts|nil # the options to pass to the notification
function vim.error(msg, opts)
    notify(msg, vim.log.levels.ERROR, opts)
end

--- Shows a notification with the HINT type
---@param msg any # the message to show
---@param opts vim.NotifyOpts|nil # the options to pass to the notification
function vim.hint(msg, opts)
    notify(msg, vim.log.levels.DEBUG, opts)
end

---@alias vim.DebounedFn fun(buffer: integer, ...) # A debounced function

--- Defers a function call for buffer in LIFO mode. If the function is called again before the timeout, the
--- timer is reset.
---@param fn vim.DebounedFn # the function to call
---@param timeout integer # the timeout in milliseconds
---@return vim.DebounedFn # the debounced function
function vim.debounce_fn(fn, timeout)
    ---@type table<integer, uv_timer_t>
    local timers = {}

    ---@type vim.DebounedFn
    return function(buffer, ...)
        buffer = buffer or vim.api.nvim_get_current_buf()

        assert(vim.api.nvim_buf_is_valid(buffer))

        local timer = timers[buffer]
        if not timer then
            timer = vim.uv.new_timer()
            timers[buffer] = timer
        else
            timer:stop()
        end

        local args = { ... }
        assert(timer:start(
            timeout,
            0,
            vim.schedule_wrap(function()
                timer:stop()

                if vim.api.nvim_buf_is_valid(buffer) then
                    vim.api.nvim_buf_call(buffer, function()
                        fn(buffer, unpack(args))
                    end)
                end
            end)
        ))
    end
end

--- Refreshes the UI
function vim.refresh_ui()
    vim.cmd.resize()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd 'tabdo wincmd ='
    vim.cmd('tabnext ' .. current_tab)
    vim.cmd 'redraw!'
end

--- Confirms an operation that requires the buffer to be saved
---@param buffer integer|nil # the buffer to confirm for or the current buffer if 0 or nil
---@param reason string|nil # the reason for the confirmation
---@return boolean # true if the buffer was saved or false if the operation was cancelled
function vim.fn.confirm_saved(buffer, reason)
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
