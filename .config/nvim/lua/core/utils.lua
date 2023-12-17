---@class utils
local M = {}

---Converts a value to a string
---@param value any # any value that will be converted to a string
---@return string|nil # the tringified version of the value
local function stringify(value)
    if value == nil then
        return nil
    elseif type(value) == 'string' then
        return value
    elseif vim.tbl_islist(value) then
        return M.tbl_join(value, ', ')
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
    elseif vim.tbl_islist(value) then
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

--- Joins all items in a list into a string
---@param items table # the list of items to join
---@param separator string|nil # the separator to use between items
---@return string|nil # the joined string
function M.tbl_join(items, separator)
    if not vim.tbl_islist(items) then
        return stringify(items)
    end

    local result = ''

    for _, item in ipairs(items) do
        if #result > 0 and separator ~= nil then
            result = result .. separator
        end

        result = result .. stringify(item)
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

--- Trigger a status update event
function M.trigger_status_update_event()
    M.trigger_user_event 'StatusUpdate'
end

--- Shows a notification
---@param msg any # the message to show
---@param type integer # the type of the notification
---@param opts? table # the options to pass to the notification
local function notify(msg, type, opts)
    assert(msg ~= nil)

    vim.schedule(function()
        vim.notify(stringify(msg) or '', type, M.tbl_merge({ title = 'NeoVim' }, opts))
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

---@type table<integer, uv_timer_t>
local deffered_buffer_timers = {}

M.on_event('BufDelete', function(evt)
    local timer = deffered_buffer_timers[evt.buf]
    if timer then
        timer:stop()
        deffered_buffer_timers[evt.buf] = nil
    end
end)

--- Defers a function call for buffer in LIFO mode. If the function is called again before the timeout, the timer is reset.
---@param buffer integer|nil # the buffer to defer the function for or the current buffer if 0 or nil
---@param fn fun(buffer: integer) # the function to call
---@param timeout integer # the timeout in milliseconds
function M.defer_unique(buffer, fn, timeout)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local timer = deffered_buffer_timers[buffer]
    if not timer then
        timer = vim.loop.new_timer()
        deffered_buffer_timers[buffer] = timer
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

--- Checks if a buffer is a special buffer
---@param buffer integer|nil # the buffer to check or the current buffer if 0 or nil
---@return boolean # true if the buffer is a special buffer, false otherwise
function M.is_special_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local filetype = vim.api.nvim_get_option_value('filetype', { buf = buffer })
    local buftype = vim.api.nvim_get_option_value('buftype', { buf = buffer })

    return (vim.tbl_contains(M.special_buffer_types, buftype) or vim.tbl_contains(M.special_file_types, filetype))
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

--- Get the highlight group for a name
---@param name string # the name of the highlight group
---@return table<string, string>|nil # the foreground color of the highlight group
function M.hl(name)
    assert(type(name) == 'string' and name ~= '')

    ---@diagnostic disable-next-line: undefined-field
    return vim.api.nvim_get_hl and vim.api.nvim_get_hl(0, { name = name, link = false }) or vim.api.nvim_get_hl_by_name(name, true)
end

--- Gets the foreground color of a highlight group
---@param name string # the name of the highlight group
---@return table<string, string>|nil # the foreground color of the highlight group
function M.hl_fg_color(name)
    local hl = M.hl(name)

    local fg = hl and (hl.fg or hl.foreground)

    return fg and { fg = string.format('#%06x', fg) }
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

return M
