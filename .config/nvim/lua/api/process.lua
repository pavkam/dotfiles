--- Provides functions for interacting with the current process.
---@class api.process
local M = {}

local fs = require 'api.fs'

--- Gets the value of an up-value of a function
---@param fn function # the function to get the up-value from
---@param name string # the name of the up-value to get
---@return any # the value of the up-value or nil if it does not exist
function M.get_up_value(fn, name)
    xassert { fn = { fn, 'callable' }, name = { name, { 'string', ['>'] = 0 } } }

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
function M.get_trace_back(level)
    xassert { level = { level, { 'integer', ['>'] = 0 } } }

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

--- Gets the trace-back of the current function
---@param level integer|nil # the level of the trace-back to get
---@return string # the formatted trace-back
function M.get_formatted_trace_back(level)
    local trace = M.get_trace_back(level)

    local result = {}
    for _, entry in pairs(trace) do
        table.insert(
            result,
            string.format(
                ' - %s %s:%d',
                fs.format_relative_path(fs.CONFIGURATION_DIRECTORY, entry.file),
                entry.fn_name,
                entry.line
            )
        )
    end

    return table.concat(result, '\n')
end

--- Global function to quit the current process
---@param exit_code integer|nil # the exit code to use when quitting (defaults to `1`)
function M.quit(exit_code)
    vim.api.nvim_command('cq' .. tostring(exit_code and exit_code or 1))
end

--- Global function to log a message as an error and quit.
---@param message string the message to log.
function M.fatal(message)
    xassert { message = { message, { 'string', ['>'] = 0 } } }

    error(string.format('fatal error has occurred: %s', message))
    error 'press any key to quit the process'

    vim.fn.getchar()

    M.quit()
end

-- Checks if the current process if at least a certain version of Neovim.
---@param major integer # the major version to check.
---@param minor integer # the minor version to check.
---@param patch integer|nil # the patch version to check.
function M.at_least_version(major, minor, patch)
    xassert {
        major = { major, { 'integer', ['>'] = 0 } },
        minor = { minor, { 'integer', ['>'] = 0 } },
        patch = { patch, { 'nil', { 'integer', ['>'] = 0 } } },
    }

    return vim.fn.has(string.format('nvim-%d.%d.%d', major, minor, patch or 0))
end

-- Checks if a command exists and can be run.
---@param command string # the command to check.
---@return boolean # whether the command exists.
function M.tool_exists(command)
    xassert { command = { command, { 'string', ['>'] = 0 } } }

    return vim.fn.executable(command) == 1
end

-- HACK: This is a workaround for the fact that lua_ls doesn't support generic classes.
-- luacheck: push ignore 631

---@class (exact) evt_slot<TArgs>: { ["continue"]: (fun(continuation: fun(args: TArgs, slot: evt_slot<TArgs>): any|nil): evt_slot<TArgs>), ["trigger"]: fun(args: TArgs|nil) } # A slot object.

-- luacheck: pop

-- Create a new raw slot (internal).
---@param handler (fun(args: any, slot: evt_slot<any>): any) | nil # the handler of the slot.
---@return evt_slot<any> # the slot object.
local function new_slot(handler)
    ---@type table<evt_slot<any>, boolean>
    local subscribers = {}

    local obj = {}

    obj.continue = function(continuation)
        local follower = new_slot(continuation)
        subscribers[follower] = true

        return follower
    end

    obj.trigger = function(args)
        args = handler and handler(args, obj) or args
        if not args then
            return
        end

        for subscriber in pairs(subscribers) do
            subscriber.trigger(args)
        end
    end

    return obj
end

---@class (exact) observe_auto_command_opts # The options for the auto command.
---@field buffer integer|nil # the buffer to target (or `nil` for all buffers).
---@field description string # the description of the auto command.
---@field group string # the group of the auto command.
---@field clear boolean|nil # whether to clear the group before creating it.
---@field patterns string[]|nil # the pattern to target (or `nil` for all patterns).

---@class (exact) vim.auto_command_data # The event data received by the auto command.
---@field id integer # the id of the auto command.
---@field event string # the event that was triggered.
---@field buf integer|nil # the buffer the event was triggered on (or `nil` of no buffer).
---@field group integer|nil # the group of the auto command.
---@field match string|nil # the match of the auto command.
---@field data table|nil # the data of the auto command.

-- Create a new slot that observes an auto command.
---@param events string[] # the list of events to trigger on.
---@param opts observe_auto_command_opts # the options for the auto command.
---@return evt_slot<vim.auto_command_data> # the slot object.
function M.observe_auto_command(events, opts)
    xassert {
        events = { events, { ['*'] = 'string' } },
        opts = {
            opts,
            {
                buffer = { 'number', 'nil' },
                description = { 'string', ['>'] = 0 },
                group = { 'string', ['>'] = 0 },
                patterns = { 'nil', { 'list', ['*'] = 'string' } },
                clear = { 'nil', 'boolean' },
            },
        },
    }

    local slot = new_slot()
    local slot_trigger = slot.trigger

    local reg_trace_back = M.get_formatted_trace_back(4)
    local auto_group_id = vim.api.nvim_create_augroup(opts.group, { clear = opts.clear or false })

    ---@type vim.api.keyset.create_autocmd
    local auto_command_opts = {
        callback = function(args)
            local ok, err = pcall(slot_trigger, args)

            if not ok then
                local formatted = table.concat(
                    #events == 1 and events[1] == 'User' and opts.patterns and #opts.patterns > 0 and opts.patterns
                        or events,
                    ', '
                )

                ide.tui.error(
                    string.format(
                        'Error in auto command `%s`: %s\nPayload:\n%s\nRegistered at:\n%s',
                        formatted,
                        err,
                        vim.inspect(args),
                        reg_trace_back
                    )
                )
            end
        end,
        group = auto_group_id,
        pattern = opts.patterns,
        desc = opts.description,
        nested = false,
    }

    -- create auto command
    vim.api.nvim_create_autocmd(events, auto_command_opts)

    slot.trigger = function(args)
        vim.api.nvim_exec_autocmds(events, { pattern = opts.patterns, modeline = false, data = args })
    end

    return slot
end

M.is_headless = vim.list_contains(vim.api.nvim_get_vvar 'argv', '--headless') or #vim.api.nvim_list_uis() == 0

-- Slot that triggers when vim is fully ready.
---@type evt_slot<{}>
M.ready = require('api.evt')
    .observe_auto_command({ 'User' }, {
        description = 'Triggers when vim is fully ready.',
        patterns = { 'LazyVimStarted' },
        group = 'process.status',
    })
    .continue(function()
        return {}
    end)

-- Slot that triggers when vim is about to quit.
---@type evt_slot<{ exit_code: integer, dying: boolean }>
M.quitting = M.observe_auto_command({ 'VimLeavePre' }, {
    description = 'Triggers when vim is ready to quit.',
    group = 'process.status',
}).continue(function()
    return {
        exit_code = vim.v.exiting == vim.v.null and 0 or vim.v.exiting --[[@as integer]],
        dying = vim.v.dying > 0,
    }
end)

-- Slot that triggers when vim receives focus.
---@type evt_slot<{}>
M.focus_gained = M.observe_auto_command({ 'FocusGained', 'TermClose', 'TermLeave', 'DirChanged' }, {
    description = 'Triggers when vim receives focus.',
    group = 'process.status',
}).continue(function()
    return {}
end)

return table.freeze(M)
