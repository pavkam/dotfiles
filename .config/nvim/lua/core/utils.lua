local icons = require 'ui.icons'

---@class core.utils
local M = {}

math.randomseed(os.time())

---Converts a value to a string
---@param value any # any value that will be converted to a string
---@return string|nil # the stringified version of the value
local function stringify(value)
    if value == nil then
        return nil
    elseif type(value) == 'string' then
        return value
    elseif vim.islist(value) then
        return table.concat(value, ', ')
    elseif type(value) == 'table' then
        return vim.inspect(value)
    elseif type(value) == 'function' then
        return stringify(value())
    else
        return tostring(value)
    end
end

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

---@class core.utils.RegisterCommandOpts
---@field desc string # the description of the command
---@field nargs integer|'*'|'?'|'+'|nil # the number of arguments the command takes
---@field bang boolean|nil # whether the command takes a bang argument
---@field default_fn string|nil # the default function if none supplied

---@class vim.CommandCallbackArgs
---@field name string # the name of the command
---@field args string # the arguments passed to the command
---@field fargs string[] # the arguments split by un-escaped white-space
---@field nargs string # the number of arguments
---@field bang boolean # whether the command was executed with a bang
---@field line1 integer # the starting line of the command range
---@field line2 integer # the final line of the command range
---@field range 0|1|2 # the number of items in the command range
---@field count integer # any count supplied
---@field reg string # the optional register, if specified
---@field mods string # the command modifiers, if any
---@field smods table # the command modifiers in a structured format

---@class core.utils.CommandCallbackArgs: vim.CommandCallbackArgs
---@field split_args string[] # the arguments split by escaped white-space
---@field lines string[] # the lines of the buffer

---@alias core.utils.CommandFunctionCallback fun(args: core.utils.CommandCallbackArgs)
---@alias core.utils.CommandFunctionCallbackSpec { fn: core.utils.CommandFunctionCallback, range: boolean|nil }
---
---@alias core.utils.CommandFunctionSpec core.utils.CommandFunctionCallback | core.utils.CommandFunctionCallbackSpec
---@alias core.utils.CommandFunctionArgs core.utils.CommandFunctionSpec|core.utils.CommandFunctionSpec[]

--- Parses a string of arguments into a table
---@param args vim.CommandCallbackArgs # the command arguments
---@return string[] # the parsed arguments
local function parse_command_args(args)
    assert(type(args) == 'table')

    local parsed_args = {}
    local in_quote = false
    local current_arg = ''

    for i = 1, #args do
        local char = args.args:sub(i, i)
        if char == '"' then
            in_quote = not in_quote
        elseif char == ' ' and not in_quote then
            if #current_arg > 0 then
                table.insert(parsed_args, current_arg)
                current_arg = ''
            end
        else
            current_arg = current_arg .. char
        end
    end

    if #current_arg > 0 then
        table.insert(parsed_args, current_arg)
    end

    return parsed_args
end

--- Extracts the lines of a buffer described by the command
---@param args vim.CommandCallbackArgs # the command arguments
---@return string[] # the lines of the buffer
local function extract_command_lines(args)
    assert(type(args) == 'table')

    ---@type string[]
    local contents = {}
    if args.range == 2 then
        contents = vim.api.nvim_buf_get_lines(0, args.line1 - 1, args.line2, false)
    elseif args.range == 1 then
        contents = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    end

    return contents
end

--- Registers a command that takes a single argument (function)
---@param name string # the name of the command
---@param fn core.utils.CommandFunctionArgs # the function(s) to call when the command is executed
---@param opts core.utils.RegisterCommandOpts|nil # the options to pass to the command
function M.register_command(name, fn, opts)
    assert(type(name) == 'string' and name ~= '')
    assert(type(fn) == 'function' or type(fn) == 'table')

    opts = opts or {}

    if type(fn) == 'function' then
        vim.api.nvim_create_user_command(
            name,
            ---@param args vim.CommandCallbackArgs
            function(args)
                fn(M.tbl_merge(args, { split_args = parse_command_args(args) }))
            end,
            {
                desc = opts.desc,
                nargs = opts.nargs,
                bang = opts.bang,
            }
        )
    elseif type(fn) == 'table' and type(fn.fn) == 'function' then
        vim.api.nvim_create_user_command(
            name,
            ---@param args vim.CommandCallbackArgs
            function(args)
                fn.fn(M.tbl_merge(args, {
                    split_args = parse_command_args(args),
                    lines = fn.range and extract_command_lines(args) or nil,
                }))
            end,
            {
                desc = opts.desc,
                nargs = opts.nargs,
                bang = opts.bang,
                range = fn.range,
            }
        )
    else
        ---@type integer|'*'|'?'|'+'|nil
        local n_args = 1
        if opts.nargs == '?' and opts.default_fn then
            n_args = '?'
        elseif opts.nargs == '*' and not opts.default_fn or opts.nargs == '+' then
            n_args = '+'
        elseif type(opts.nargs) == 'number' then
            if opts.default_fn then
                n_args = opts.nargs
            else
                n_args = n_args + opts.nargs
            end
        end

        local supports_range = #vim.tbl_filter(function(f)
            return type(f) == 'table' and f.range
        end, fn) > 0

        vim.api.nvim_create_user_command(
            name,
            ---@param args core.utils.CommandCallbackArgs
            function(args)
                local func_or_spec = fn[args.fargs[1] or opts.default_fn]
                if not func_or_spec then
                    M.error(string.format('Unknown function `%s`', args.args))
                    return
                end

                local func = type(func_or_spec) == 'function' and func_or_spec or func_or_spec.fn

                if func then
                    func(M.tbl_merge(args, {
                        split_args = parse_command_args(args),
                        lines = type(func_or_spec) == 'table' and func_or_spec.range and extract_command_lines(args)
                            or nil,
                    }))
                end
            end,
            {
                desc = opts.desc,
                nargs = n_args,
                bang = opts.bang,
                range = supports_range,
                complete = function(arg_lead)
                    local completions = vim.tbl_keys(fn)
                    local matches = {}

                    for _, value in ipairs(completions) do
                        if value:sub(1, #arg_lead) == arg_lead then
                            table.insert(matches, value)
                        end
                    end

                    return matches
                end,
            }
        )
    end
end

---@class core.utils.NotifyOpts # the options to pass to the notification
---@field prefix_icon string|nil # the icon to prefix the message with
---@field suffix_icon string|nil # the icon to suffix the message with
---@field title string|nil # the title of the notification

--- Shows a notification
---@param msg any # the message to show
---@param level integer # the level of the notification
---@param opts core.utils.NotifyOpts|nil # the options to pass to the notification
local function notify(msg, level, opts)
    msg = stringify(msg) or ''

    if opts and opts.prefix_icon then
        msg = opts.prefix_icon .. ' ' .. msg
    end

    if opts and opts.suffix_icon then
        msg = msg .. ' ' .. opts.suffix_icon
    end

    local title = opts and opts.title or 'NeoVim'

    vim.schedule(function()
        vim.notify(stringify(msg) or '', level, { title = title })
    end)
end

--- Shows a notification with the INFO type
---@param msg any # the message to show
---@param opts core.utils.NotifyOpts|nil # the options to pass to the notification
function M.info(msg, opts)
    notify(msg, vim.log.levels.INFO, opts)
end

--- Shows a notification with the WARN type
---@param msg any # the message to show
---@param opts core.utils.NotifyOpts|nil # the options to pass to the notification
function M.warn(msg, opts)
    notify(msg, vim.log.levels.WARN, opts)
end

--- Shows a notification with the ERROR type
---@param msg any # the message to show
---@param opts core.utils.NotifyOpts|nil # the options to pass to the notification
function M.error(msg, opts)
    notify(msg, vim.log.levels.ERROR, opts)
end

--- Shows a notification with the HINT type
---@param msg any # the message to show
---@param opts core.utils.NotifyOpts|nil # the options to pass to the notification
function M.hint(msg, opts)
    notify(msg, vim.log.levels.DEBUG, opts)
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

---@class (exact) core.utils.GetListedBufferOpts
---@field loaded boolean|nil # whether to get only loaded buffers (default) true
---@field listed boolean|nil # whether to get only listed buffers (default) true

--- Gets the list of listed file buffers
---@param opts core.utils.GetListedBufferOpts|nil # the options to get the buffers
---@return integer[] # the list of buffers
function M.get_listed_buffers(opts)
    opts = opts or {}
    opts.loaded = opts.loaded == nil and true or opts.loaded
    opts.listed = opts.listed == nil and true or opts.listed

    return vim.iter(vim.api.nvim_list_bufs())
        :filter(
            ---@param b integer
            function(b)
                if not vim.api.nvim_buf_is_valid(b) then
                    return false
                end
                if opts.listed and not vim.api.nvim_get_option_value('buflisted', { buf = b }) then
                    return false
                end
                if opts.loaded and not vim.api.nvim_buf_is_loaded(b) then
                    return false
                end

                return true
            end
        )
        :totable()
end

--- Checks if a buffer is loaded
--- @param buffer integer| nil # the buffer to check or the current buffer if 0 or nil
function M.buffer_is_loaded(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()
    return vim.api.nvim_buf_is_valid(buffer) and vim.api.nvim_buf_is_loaded(buffer)
end

--- Gets the buffer by its index in the list of listed buffers
---@param index integer # the index of the buffer to get
---@return integer|nil # the index of the buffer in the list of listed buffers or nil if the buffer is not listed
function M.get_buffer_by_index(index)
    assert(type(index) == 'number' and index > 0)

    for i, b in ipairs(M.get_listed_buffers { loaded = false }) do
        if i == index then
            return b
        end
    end

    return nil
end

--- Removes a buffer
---@param buffer integer|nil # the buffer to remove or the current buffer if 0 or nil
function M.remove_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local should_remove = M.confirm_saved(0, 'closing')
    if should_remove then
        local buffers = M.get_listed_buffers { loaded = false }

        require('mini.bufremove').delete(buffer, true)

        -- Special code to manage alpha
        if M.has_plugin 'alpha-nvim' then
            if #buffers == 1 and buffers[1] == buffer then
                require('alpha').start()
                vim.schedule(function()
                    for _, b in ipairs(M.get_listed_buffers()) do
                        vim.api.nvim_buf_delete(b, { force = true })
                    end
                end)
            end
        end
    end
end

--- Removes other buffers (except the current one)
---@param buffer integer|nil # the buffer to remove or the current buffer if 0 or nil
function M.remove_other_buffers(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    for _, b in ipairs(M.get_listed_buffers { loaded = false }) do
        if b ~= buffer then
            M.remove_buffer(b)
        end
    end
end

M.special_file_types = {
    'neo-tree',
    'dap-float',
    'dap-repl',
    'dapui_console',
    'dapui_watches',
    'dapui_stacks',
    'dapui_breakpoints',
    'dapui_scopes',
    'PlenaryTestPopup',
    'help',
    'lspinfo',
    'man',
    'notify',
    'noice',
    'Outline',
    'qf',
    'query',
    'spectre_panel',
    'startuptime',
    'tsplayground',
    'checkhealth',
    'Trouble',
    'terminal',
    'neotest-summary',
    'neotest-output',
    'neotest-output-panel',
    'WhichKey',
    'TelescopePrompt',
    'TelescopeResults',
}

M.special_buffer_types = {
    'prompt',
    'nofile',
    'terminal',
    'help',
}

M.transient_buffer_types = {
    'nofile',
    'terminal',
}

M.transient_file_types = {
    'gitcommit',
    'gitrebase',
    'hgcommit',
}

--- Checks if a buffer is a special buffer
---@param buffer integer|nil # the buffer to check or the current buffer if 0 or nil
---@return boolean # true if the buffer is a special buffer, false otherwise
function M.is_special_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local filetype = vim.api.nvim_get_option_value('filetype', { buf = buffer })
    local buftype = vim.api.nvim_get_option_value('buftype', { buf = buffer })

    return buftype ~= ''
        and (vim.tbl_contains(M.special_buffer_types, buftype) or vim.tbl_contains(M.special_file_types, filetype))
end

--- Checks if a buffer is a transient buffer (a file which we should not deal with)
---@param buffer integer|nil # the buffer to check or the current buffer if 0 or nil
---@return boolean # true if the buffer is a transient buffer, false otherwise
function M.is_transient_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local filetype = vim.api.nvim_get_option_value('filetype', { buf = buffer })
    local buftype = vim.api.nvim_get_option_value('buftype', { buf = buffer })

    if buftype == '' and filetype == '' then
        return true
    end

    return (vim.tbl_contains(M.transient_buffer_types, buftype) or vim.tbl_contains(M.transient_file_types, filetype))
end

--- Checks whether a buffer is a regular buffer (normal file)
---@param buffer integer|nil # the buffer to check, or the current buffer if 0 or nil
---@return boolean # whether the buffer is valid for formatting
function M.is_regular_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()
    return vim.api.nvim_buf_is_valid(buffer) and not M.is_special_buffer(buffer) and not M.is_transient_buffer(buffer)
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
