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
    xassert { level = { level, { 'nil', { 'integer', ['>'] = 0 } } } }

    local trace = level and debug.traceback('', (level or 1) + 1) or debug.traceback()

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
    -- TODO: merge with the other function
    local trace = M.get_trace_back((level or 1) + 1)

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

-- TODO: table.module
M.is_headless = vim.list_contains(vim.api.nvim_get_vvar 'argv', '--headless') or #vim.api.nvim_list_uis() == 0

-- Triggered when the process is fully ready.
---@param callback fun() # the callback to trigger.
---@return fun() # the unsubscribe function.
function M.on_ready(callback)
    xassert { callback = { callback, 'callable' } }

    return require('api.async').subscribe_event('@LazyVimStarted', callback, {
        description = 'Triggers when vim is fully ready.',
        group = 'process.status',
        once = true,
    })
end

-- Triggered when the process is fully ready.
---@param callback fun(args: { exit_code: integer, dying: boolean }) # the callback to trigger.
---@return fun() # the unsubscribe function.
function M.on_exit(callback)
    xassert { callback = { callback, 'callable' } }

    return require('api.async').subscribe_event('VimLeavePre', function(args)
        callback(table.merge(args, {
            exit_code = vim.v.exiting == vim.v.null and 0 or vim.v.exiting --[[@as integer]],
            dying = vim.v.dying > 0,
        }))
    end, {
        description = 'Triggers when vim is about to exit.',
        group = 'process.status',
        once = true,
    })
end

-- Triggered when the application receives focus.
---@param callback fun() # the callback to trigger.
---@return fun() # the unsubscribe function.
function M.on_focus(callback)
    xassert { callback = { callback, 'callable' } }

    return require('api.async').subscribe_event({ 'FocusGained', 'TermClose', 'TermLeave', 'DirChanged' }, callback, {
        description = 'Triggers when vim receives focus.',
        group = 'process.status',
    })
end

return table.freeze(M)
