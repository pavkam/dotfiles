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

--- Checks if a list contains a value
---@param list any[] # the list to check
---@param what any # the value to check for
---@return boolean # true if the list contains the value, false otherwise
function M.list_contains(list, what)
    assert(vim.tbl_islist(list))

    for _, val in ipairs(list) do
        if val == what then
            return true
        end
    end

    return false
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

--- Shallows copies a table
---@param table table # the table to copy
---@return table # the copied table
function M.tbl_copy(table)
    assert(type(table) == 'table')

    return vim.tbl_extend('force', {}, table)
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

--- Converts any value to a string
---@vararg any # the values to stringify
---@return string|nil # the stringified version of the value
function M.stringify(...)
    local args = { ... }
    if #args == 1 then
        return stringify(...)
    elseif #args == 0 then
        return nil
    else
        return M.tbl_join(args, ' ')
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
---@param force boolean # whether to force the keymaps to be set even if they are already set
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

--- Runs a given callback after a given number of milliseconds
---@param ms number # the number of milliseconds to wait
---@param callback function # the callback to call
function M.debounce(ms, callback)
    assert(type(ms) == 'number' and ms > 0)
    assert(type(callback) == 'function')

    local timer = vim.loop.new_timer()
    local wrapped = vim.schedule_wrap(callback)

    timer:start(ms, 0, function()
        timer:stop()
        wrapped()
    end)
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
function M.notify(msg, type, opts)
    assert(msg ~= nil)

    vim.schedule(function()
        vim.notify(M.stringify(msg) or '', type, M.tbl_merge({ title = 'NeoVim' }, opts))
    end)
end

--- Shows a notification with the INFO type
---@param msg any # the message to show
function M.info(msg)
    M.notify(msg, vim.log.levels.INFO)
end

--- Shows a notification with the WARN type
---@param msg any # the message to show
function M.warn(msg)
    M.notify(msg, vim.log.levels.WARN)
end

--- Shows a notification with the ERROR type
---@param msg any # the message to show
function M.error(msg)
    M.notify(msg, vim.log.levels.ERROR)
end

--- Expands a target of any command to a buffer and a path
---@param target integer|function|string|nil # the target to expand
---@return integer, string|nil # the buffer and the path
function M.expand_target(target)
    if type(target) == 'function' then
        target = target()
    end

    if type(target) == 'number' then
        return target, vim.api.nvim_buf_get_name(target)
    else
        local path = M.stringify(target)
        return vim.api.nvim_get_current_buf(), path and vim.loop.fs_realpath(path) or nil
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

    local file = io.open(path, 'r')
    if file then
        file:close()
        return true
    else
        return false
    end
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

--- Executes a given command and returns the output
---@param cmd string|string[] # the command to execute
---@param show_error boolean # whether to show an error if the command fails
---@return string|nil # the output of the command or nil if the command failed
function M.cmd(cmd, show_error)
    cmd = M.to_list(cmd)
    ---@cast cmd string[]

    if vim.fn.has 'win32' == 1 then
        cmd = vim.list_extend({ 'cmd.exe', '/C' }, cmd)
    end

    local result = vim.fn.system(cmd)
    local success = vim.api.nvim_get_vvar 'shell_error' == 0

    if not success and (show_error == nil or show_error) then
        M.error(string.format('Error running command *%s*\nError message:\n**%s**', M.tbl_join(cmd, ' '), result))
    end

    return success and result:gsub('[\27\155][][()#;?%d]*[A-PRZcf-ntqry=><~]', '') or nil
end

--- Checks if a file is under git
---@param file_name string # the name of the file to check
---@return boolean # true if the file is under git, false otherwise
function M.file_is_under_git(file_name)
    assert(type(file_name) == 'string' and file_name ~= '')

    return M.cmd({ 'git', '-C', vim.fn.fnamemodify(file_name, ':p:h'), 'rev-parse' }, false) ~= nil
end

--- Gets the foreground color of a highlight group
---@param name string # the name of the highlight group
---@return table<string, string>|nil # the foreground color of the highlight group
function M.hl_fg_color(name)
    assert(type(name) == 'string' and name ~= '')

    ---@diagnostic disable-next-line: undefined-field
    local hl = vim.api.nvim_get_hl and vim.api.nvim_get_hl(0, { name = name, link = false }) or vim.api.nvim_get_hl_by_name(name, true)
    local fg = hl and hl.fg or hl.foreground

    return fg and { fg = string.format('#%06x', fg) }
end

local icons = require 'utils.icons'

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

return M
