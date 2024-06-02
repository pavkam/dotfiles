local syntax = require 'editor.syntax'

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

--- Flattens a table
--- @param tbl table # the table to flatten
--- @param key string|nil # the initial prefix to use for the flattened table. All keys are concatenated with a dot.
--- @return table<string, any> # the flattened table
function M.flatten(tbl, key)
    if type(tbl) ~= 'table' then
        return { [key] = tbl }
    end

    ---@type table<string, any>
    local result = {}

    for p, v in pairs(tbl) do
        for pr, pv in pairs(M.flatten(v, p)) do
            local k = key and key .. '.' .. pr or pr
            result[k] = pv
        end
    end

    return result
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

local group_index = 0

--- Creates an auto command that triggers on a given list of events
---@param events string|string[] # the list of events to trigger on
---@param callback function # the callback to call when the event is triggered
---@param target table|string|number|nil # the target to trigger on
---@return number # the group id of the created group
function M.on_event(events, callback, target)
    assert(type(callback) == 'function')

    events = M.to_list(events)
    target = M.to_list(target)

    -- create group
    local group_name = 'pavkam_' .. group_index
    group_index = group_index + 1
    local group = vim.api.nvim_create_augroup(group_name, { clear = true })

    local opts = {
        callback = function(evt)
            callback(evt, group)
        end,
        group = group,
    }

    -- decide on the target
    if type(target) == 'number' then
        opts.buffer = target
    elseif target then
        opts.pattern = target
    end

    -- create auto command
    vim.api.nvim_create_autocmd(events, opts)

    return group
end

--- Creates an auto command that triggers on a given list of user events
---@param events string|table # the list of events to trigger on
---@param callback function # the callback to call when the event is triggered
---@return number # the group id of the created group
function M.on_user_event(events, callback)
    events = M.to_list(events)
    return M.on_event('User', function(evt)
        callback(evt.match, evt)
    end, events)
end

--- Creates an auto command that triggers on focus gained
---@param callback function # the callback to call when the event is triggered
function M.on_focus_gained(callback)
    assert(type(callback) == 'function')
    M.on_event({ 'FocusGained', 'TermClose', 'TermLeave' }, callback)
end

--- Creates an auto command that triggers on global status update event
---@param callback function # the callback to call when the event is triggered
---@return number # the group id of the created group
function M.on_status_update_event(callback)
    return M.on_event('User', callback, 'StatusUpdate')
end

--- Allows attaching keymaps in a given buffer alone.
---@param file_types string|table|nil # the list of file types to attach the keymaps to
---@param callback fun(set: fun(mode: string|table|nil, lhs: string, rhs: string|function, opts: table)) # the callback to call when the event is triggered
---@param force boolean|nil # whether to force the keymaps to be set even if they are already set
---@return number # the group id of the created group
function M.attach_keymaps(file_types, callback, force)
    assert(type(callback) == 'function')

    if file_types == nil then
        file_types = '*'
    else
        file_types = M.to_list(file_types)
    end

    return M.on_event('FileType', function(evt)
        if file_types == '*' and M.is_special_buffer(evt.buf) then
            return
        end

        local mapper = function(mode, lhs, rhs, opts)
            ---@diagnostic disable-next-line: param-type-mismatch
            local has_mapping = not vim.tbl_isempty(vim.fn.maparg(lhs, mode, 0, 1))
            if not has_mapping or force then
                vim.keymap.set(mode, lhs, rhs, M.tbl_merge({ buffer = evt.buf }, opts or {}))
            end
        end
        callback(mapper)
    end, file_types)
end

--- Trigger a user event
---@param event string # the name of the event to trigger
---@param data any # the data to pass to the event
function M.trigger_user_event(event, data)
    vim.api.nvim_exec_autocmds('User', { pattern = event, modeline = false, data = data })
end

---@class core.utils.RegisterCommandOpts
---@field desc string # the description of the command
---@field n_args integer|'*'|'?'|nil # the number of arguments the command takes
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

---@alias core.utils.CommandFunctionSpec fun(args: core.utils.CommandCallbackArgs) | { fn: fun(args: core.utils.CommandCallbackArgs), range: boolean|nil }
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
                nargs = opts.n_args,
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
                nargs = opts.n_args,
                bang = opts.bang,
                range = fn.range,
            }
        )
    else
        ---@type integer|'*'|'?'|'+'|nil
        local n_args = 1
        if opts.n_args == '?' and opts.default_fn then
            n_args = '?'
        elseif opts.n_args == '*' and not opts.default_fn then
            n_args = '+'
        elseif type(opts.n_args) == 'number' then
            if opts.default_fn then
                n_args = opts.n_args
            else
                n_args = n_args + opts.n_args
            end
        end

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
                        lines = type(func_or_spec) == 'table' and func_or_spec.range and extract_command_lines(args) or nil,
                    }))
                end
            end,
            {
                desc = opts.desc,
                nargs = n_args,
                bang = opts.bang,
                range = #vim.tbl_filter(function(f)
                    return type(f) == 'table' and f.range
                end, fn) > 0,
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

--- Trigger a status update event
function M.trigger_status_update_event()
    M.trigger_user_event 'StatusUpdate'
end

--- Shows a notification
---@param msg any # the message to show
---@param level integer # the level of the notification
---@param opts table<string, any>|nil # the options to pass to the notification
local function notify(msg, level, opts)
    vim.schedule(function()
        vim.notify(stringify(msg) or '', level, M.tbl_merge({ title = 'NeoVim' }, opts))
    end)
end

--- Shows a notification with the INFO type
---@param msg any # the message to show
function M.info(msg)
    notify(msg, vim.log.levels.INFO)
end

--- Shows a notification with the WARN type
---@param msg any # the message to show
function M.warn(msg)
    notify(msg, vim.log.levels.WARN)
end

--- Shows a notification with the ERROR type
---@param msg any # the message to show
function M.error(msg)
    notify(msg, vim.log.levels.ERROR)
end

--- Shows a notification with the HINT type
---@param msg any # the message to show
function M.hint(msg)
    notify(msg, vim.log.levels.DEBUG)
end

---@type table<integer, uv_timer_t>
local differed_buffer_timers = {}

M.on_event('BufDelete', function(evt)
    local timer = differed_buffer_timers[evt.buf]
    if timer then
        timer:stop()
        differed_buffer_timers[evt.buf] = nil
    end
end)

--- Defers a function call for buffer in LIFO mode. If the function is called again before the timeout, the timer is reset.
---@param buffer integer|nil # the buffer to defer the function for or the current buffer if 0 or nil
---@param fn fun(buffer: integer) # the function to call
---@param timeout integer # the timeout in milliseconds
function M.defer_unique(buffer, fn, timeout)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local timer = differed_buffer_timers[buffer]
    if not timer then
        timer = vim.loop.new_timer()
        differed_buffer_timers[buffer] = timer
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

--- Gets the value of an upvalue of a function
---@param fn function # the function to get the upvalue from
---@param name string # the name of the upvalue to get
---@return any # the value of the upvalue or nil if it does not exist
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

--- Expands a target of any command to a buffer and a path
---@param target integer|string|nil # the target to expand
---@return integer, string # the buffer and the path
function M.expand_target(target)
    if type(target) == 'number' or target == nil then
        target = target or vim.api.nvim_get_current_buf()
        return target, vim.api.nvim_buf_get_name(target)
    else
        local path = vim.fn.expand(target --[[@as string]])
        return vim.api.nvim_get_current_buf(), vim.loop.fs_realpath(vim.fn.expand(path)) or path
    end
end

--- Gets the list of listed file buffers
---@return integer[] # the list of buffers
function M.get_listed_buffers()
    return vim.tbl_filter(function(b)
        return (vim.api.nvim_buf_is_valid(b) and vim.api.nvim_buf_is_loaded(b) and vim.bo[b].buflisted)
    end, vim.api.nvim_list_bufs())
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

    return buftype ~= '' and (vim.tbl_contains(M.special_buffer_types, buftype) or vim.tbl_contains(M.special_file_types, filetype))
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
    assert(type(path) == 'string' and path ~= '')

    local stat = vim.loop.fs_stat(path)
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

--- Reads a text file
---@param path string # the path to the file to read
---@return string|nil # the content of the file or nil if the file does not exist
function M.read_text_file(path)
    assert(type(path) == 'string' and path ~= '')

    local file = io.open(path, 'rb')
    if not file then
        return nil
    end

    local content = file:read '*a'
    file:close()

    return content
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

--- Get the highlight group for a name
---@param name string # the name of the highlight group
---@return table<string, string>|nil # the foreground color of the highlight group
function M.hl(name)
    assert(type(name) == 'string' and name ~= '')

    return vim.api.nvim_get_hl(0, { name = name, link = false })
end

--- Extracts the color and attributes from a highlight group.
---@param name string # the name of the highlight group
---@return { fg: string, gui: string }|nil # the color and attributes of the highlight group
function M.hl_fg_color_and_attrs(name)
    assert(type(name) == 'string' and name ~= '')

    local hl = M.hl(name)

    if not hl then
        return nil
    end

    local fg = hl.fg or hl.foreground or 0
    local attrs = {}

    for _, attr in ipairs { 'italic', 'bold', 'undercurl', 'underdotted', 'underlined', 'strikethrough' } do
        if hl[attr] then
            table.insert(attrs, attr)
        end
    end

    return { fg = string.format('#%06x', fg), gui = table.concat(attrs, ',') }
end

local icons = require 'ui.icons'

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
        local message = reason and 'Save changes to %q before %s?' or 'Save changes to %q?'
        local choice = vim.fn.confirm(string.format(message, vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buffer), ':t'), reason), '&Yes\n&No\n&Cancel')

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

--- Runs a function with the current visual selection
---@param buffer integer|nil # the buffer to run the function for or the current buffer if 0 or nil
---@param callback fun(restore_callback: fun(command?: string)) # the callback to call with the selection
function M.run_with_visual_selection(buffer, callback)
    assert(type(callback) == 'function')

    if vim.api.nvim_get_mode().mode ~= 'v' then
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
                vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(string.format(':%s<cr>', command), true, false, true), 'n', false)
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

--- Feed keys to neovim
---@param keys string # the keys to feed
---@param mode string|nil # the mode to feed the keys in
function M.feed_keys(keys, mode)
    assert(type(keys) == 'string')
    mode = mode or 'n'

    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), mode, false)
end

--- Formats the term_codes to be human-readable
---@param str string # the string to format
function M.format_term_codes(str)
    assert(type(str) == 'string')

    return str:gsub(string.char(9), '<TAB>'):gsub('', '<C-F>'):gsub(' ', '<Space>')
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
