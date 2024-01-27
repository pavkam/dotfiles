local utils = require 'core.utils'
local progress = require 'ui.progress'
local esc = require('extras.markdown').escape

local progress_class = 'shell'

---@class core.shell
local M = {}

---@type table<string, LazyFloat>
M.terminals = {}

--- Creates a floating terminal
---@param cmd string # the command to run in the terminal
---@param opts? table # the options to pass to the terminal
---@return LazyFloat # the created terminal
function M.floating(cmd, opts)
    assert(type(cmd) == 'string' and cmd ~= '')

    local cwd = vim.loop.cwd()

    opts = utils.tbl_merge({
        ft = 'lazyterm',
        size = { width = 0.9, height = 0.9 },
        cwd = cwd and vim.loop.fs_realpath(cwd),
    }, opts or {}, { persistent = true })

    local key = vim.inspect {
        cmd = cmd or 'shell',
        cwd = opts.cwd,
        env = opts.env,
        count = vim.v.count1,
    }

    if M.terminals[key] and M.terminals[key]:buf_valid() then
        M.terminals[key]:toggle()
    else
        M.terminals[key] = require('lazy.util').float_term(cmd, opts)

        local buf = M.terminals[key].buf
        vim.api.nvim_create_autocmd('BufEnter', {
            buffer = buf,
            callback = function()
                vim.cmd.startinsert()
            end,
        })
    end

    return M.terminals[key]
end

---@class core.shell.RunningProcess
---@field cmd string # the command that is running
---@field args string[] # the arguments that are running

---@type table<integer, core.shell.RunningProcess>
M.running_processes = {}

--- Executes a given command asynchronously and returns the output
---@param cmd string # the command to execute
---@param args string[] # the arguments to pass to the command
---@param input string|string[]|nil # the input to pass to the command
---@param callback fun(exit_code_or_error: integer|nil, stdout: string[], stderr: string[]) # the callback to call when the command finishes
---@param opts? { cwd: string | nil } # the options to pass to the command
local function async_cmd(cmd, args, input, callback, opts)
    local stdin = input and assert(vim.loop.new_pipe(false), 'Failed to create stdin pipe')
    local stdout = assert(vim.loop.new_pipe(false), 'Failed to create stdout pipe')
    local stderr = assert(vim.loop.new_pipe(false), 'Failed to create stderr pipe')

    opts = opts or {}

    ---@type uv_process_t|nil
    local handle

    ---@type integer|nil
    local pid

    local function cleanup()
        if stdin then
            stdin:shutdown()
            stdin:close()
        end

        if stdout then
            stdout:read_stop()
            stdout:shutdown()
            stdout:close()
        end
        if stderr then
            stderr:read_stop()
            stderr:shutdown()
            stderr:close()
        end
        if handle then
            M.running_processes[
                pid --[[@as integer]]
            ] = nil

            if next(M.running_processes) ~= nil then
                progress.register_task(progress_class, {
                    ctx = vim.tbl_values(M.running_processes),
                })
            end

            handle:close()
        end
    end

    ---@type string|nil
    local write_error = nil
    ---@type string|nil
    local read_error = nil
    ---@type string[]
    local stdout_lines = {}
    ---@type string[]
    local stderr_lines = {}
    ---@type string|integer
    local spawn_error_or_pid

    handle, spawn_error_or_pid = vim.loop.spawn(
        cmd,
        {
            args = args,
            stdio = { stdin, stdout, stderr },
            cwd = opts.cwd or vim.loop.cwd(),
        },
        vim.schedule_wrap(function(code)
            cleanup()
            callback(read_error or code, stdout_lines, stderr_lines)
        end)
    )

    if not handle then
        cleanup()
        utils.error(
            string.format('Failed to spawn command *"%s"* with arguments *"%s"*: **%s**!', esc(cmd), esc(utils.tbl_join(args, ' ')), esc(spawn_error_or_pid))
        )
        return
    end

    pid = spawn_error_or_pid --[[@as integer]]

    M.running_processes[pid] = { cmd = cmd, args = args }
    progress.register_task(progress_class, {
        ctx = vim.tbl_values(M.running_processes),
        fn = function()
            return next(M.running_processes) ~= nil
        end,
        timeout = 60 * 1000,
    })

    local stdin_write_success, stdin_write_error
    if stdin then
        stdin_write_success, stdin_write_error = stdin:write(input --[[@as string]], function(err)
            write_error = write_error or err
        end)
        stdin_write_success, stdin_write_error = stdin:shutdown()
    end

    local stdout_read_success, stdout_read_error = stdout:read_start(function(err, data)
        if err or read_error then
            read_error = read_error or err
            return
        end

        if data then
            for _, d in pairs(vim.split(data, '\n')) do
                table.insert(stdout_lines, d)
            end
        end
    end)

    local stderr_read_success, stderr_read_error = stderr:read_start(function(err, data)
        if err or read_error then
            read_error = read_error or err
            return
        end

        if data then
            for _, d in pairs(vim.split(data, '\n')) do
                table.insert(stderr_lines, d)
            end
        end
    end)

    if (stdin and not stdin_write_success) or not stdout_read_success or not stderr_read_success then
        cleanup()
        utils.error(
            string.format(
                'Failed to read/write from/to pipes for command *"%s"*: **%s**!',
                esc(cmd),
                esc(stdin_write_error or stdout_read_error or stderr_read_error)
            )
        )
    end
end

--- Executes a given command asynchronously and returns the output
---@param cmd string # the command to execute
---@param args string[]|nil # the arguments to pass to the command
---@param input string|string[]|nil # the input to pass to the command
---@param callback fun(stdout: string[], code: integer) # the callback to call when the command finishes
---@param opts? { cwd: string | nil, ignore_codes: integer[]|nil, no_checktime: boolean|nil } # the options to pass to the command
function M.async_cmd(cmd, args, input, callback, opts)
    opts = opts or {}
    args = args or {}

    local ignore_codes = opts.ignore_codes and utils.to_list(opts.ignore_codes) or { 0 }

    async_cmd(cmd, args, input, function(code, stdout, stderr)
        if not opts.no_checktime then
            vim.cmd.checktime()
        end

        if #stdout > 0 and stdout[#stdout] == '' then
            table.remove(stdout, #stdout)
        end
        if #stderr > 0 and stderr[#stderr] == '' then
            table.remove(stderr, #stderr)
        end

        if not vim.tbl_contains(ignore_codes, code) then
            ---@type string|nil
            local message
            if #stderr > 0 then
                message = utils.tbl_join(stderr, '\n') or ''
            elseif #stdout > 0 then
                message = utils.tbl_join(stdout, '\n') or ''
            end

            if message then
                utils.error(
                    string.format(
                        'Error running command `%s %s` (error: **%s**):\n\n```\n%s\n```',
                        esc(cmd),
                        esc(table.concat(args, ' ')),
                        tostring(code),
                        esc(message)
                    )
                )
            else
                utils.error(string.format('Error running command `%s %s` (error: **%s**)', esc(cmd), esc(table.concat(args, ' ')), tostring(code)))
            end

            return
        end

        callback(stdout, code --[[@as integer]])
    end, { cwd = opts.cwd })
end

--- Gets the progress of running shell tasks
---@return string|nil,string[]|core.shell.RunningProcess[]|nil # the progress of the shell tasks or nil if not running
function M.progress()
    return progress.status(progress_class)
end

---@class core.shell.GrepResult
---@field filename string # the name of the file
---@field lnum integer # the line number
---@field col integer # the column number
---@field text string # the text of the line

--- Greps a given term in a given directory
---@param term string # the term to grep for
---@param dir string|nil # the directory to grep in or the current directory if nil
---@param callback fun(results: core.shell.GrepResult[]) # the callback to call when the command finishes
function M.grep_dir(term, dir, callback)
    dir = dir or vim.loop.cwd()
    M.async_cmd('rg', { term, dir, '--vimgrep', '--no-heading', '--smart-case' }, nil, function(stdout)
        ---@type core.shell.GrepResult[]
        local results = {}
        for _, line in ipairs(stdout) do
            local file, line_number, column_number, snippet = line:match '^(.+):(%d+):(%d+):(.*)$'
            if file and line_number and column_number and snippet then
                table.insert(results, {
                    filename = file,
                    lnum = line_number,
                    col = column_number,
                    text = snippet,
                })
            end
        end

        callback(results)
    end, { ignore_codes = { 0, 1 } })
end

--- Parses a string of arguments into a table
---@param args string # the string of arguments to parse
---@return string[] # the parsed arguments
local function parse_args(args)
    local parsed_args = {}
    local in_quote = false
    local current_arg = ''

    for i = 1, #args do
        local char = args:sub(i, i)
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

vim.api.nvim_create_user_command('Yolo', function(args)
    local cmd_line = parse_args(args.args)
    if #cmd_line == 0 then
        error 'No command specified'
    end

    local cmd_line_desc = table.concat(cmd_line, ' ')
    local cmd = table.remove(cmd_line, 1)

    ---@type string[] | nil
    local contents
    if args.range == 2 then
        contents = vim.api.nvim_buf_get_lines(0, args.line1 - 1, args.line2, false)
    elseif args.range == 1 then
        contents = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    end

    M.async_cmd(cmd, cmd_line, contents, function(output)
        if not args.bang then
            if #output > 0 then
                local message = table.concat(output, '\n')
                utils.info(string.format('Command "%s" finished:\n\n```sh\n%s\n```', esc(cmd_line_desc), esc(message)))
            else
                utils.info(string.format('Command "%s" finished', esc(cmd_line_desc)))
            end
        else
            if args.range == 2 then
                vim.api.nvim_buf_set_lines(0, args.line1 - 1, args.line2, false, output)
            elseif args.range == 1 then
                vim.api.nvim_buf_set_lines(0, 0, -1, false, output)
            else
                -- insert at cursor position
                vim.api.nvim_put(output, 'c', true, true)
            end
        end
    end)
end, { desc = 'Run a shell command', bang = true, nargs = '+', range = true })

vim.cmd.cnoreabbrev('y', 'Yolo')

return M
