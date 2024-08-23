require 'api.vim'
require 'api.buf'

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
