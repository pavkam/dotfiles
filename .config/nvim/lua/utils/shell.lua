local utils = require 'utils'

---@class utils.shell
local M = {}

---@type table<string, LazyFloat>
M.terminals = {}

--- Creates a floating terminal
---@param cmd string # the command to run in the terminal
---@param opts? table # the options to pass to the terminal
---@return LazyFloat # the created terminal
function M.floating(cmd, opts)
    assert(type(cmd) == 'string' and cmd ~= '')

    opts = utils.tbl_merge({
        ft = 'lazyterm',
        size = { width = 0.9, height = 0.9 },
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

--- Executes a given command and returns the output
---@param cmd string|string[] # the command to execute
---@param show_error boolean # whether to show an error if the command fails
---@return string|nil # the output of the command or nil if the command failed
function M.cmd(cmd, show_error)
    cmd = utils.to_list(cmd)
    ---@cast cmd string[]

    if vim.fn.has 'win32' == 1 then
        cmd = vim.list_extend({ 'cmd.exe', '/C' }, cmd)
    end

    local result = vim.fn.system(cmd)
    local success = vim.api.nvim_get_vvar 'shell_error' == 0

    if not success and (show_error == nil or show_error) then
        utils.error(string.format('Error running command *%s*\nError message:\n**%s**', utils.tbl_join(cmd, ' '), result))
    end

    return success and result:gsub('[\27\155][][()#;?%d]*[A-PRZcf-ntqry=><~]', '') or nil
end

--- Executes a given command asynchronously and returns the output
---@param cmd string # the command to execute
---@param args string[] # the arguments to pass to the command
---@param callback fun(exit_code_or_error: integer|nil, stdout: string[], stderr: string[]) # the callback to call when the command finishes
local function async_cmd(cmd, args, callback)
    local stdout = assert(vim.loop.new_pipe(false), 'Failed to create stdout pipe')
    local stderr = assert(vim.loop.new_pipe(false), 'Failed to create stderr pipe')

    ---@type uv_process_t|nil
    local handle

    local function cleanup()
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
            handle:close()
        end
    end

    ---@type string|nil
    local read_error = nil
    ---@type string[]
    local stdout_lines = {}
    ---@type string[]
    local stderr_lines = {}
    ---@type string|integer
    local spawn_error

    handle, spawn_error = vim.loop.spawn(
        cmd,
        {
            args = args,
            stdio = { nil, stdout, stderr },
        },
        vim.schedule_wrap(function(code)
            cleanup()
            callback(read_error or code, stdout_lines, stderr_lines)
        end)
    )

    if not handle then
        cleanup()
        utils.error(string.format('Failed to spawn command *"%s"* with arguments *"%s"*: **%s**!', cmd, utils.tbl_join(args, ' '), spawn_error))
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

    if not stdout_read_success or not stderr_read_success then
        cleanup()
        utils.error(string.format('Failed to read from pipes for command *"%s"*: **%s**!', cmd, stdout_read_error or stderr_read_error))
    end
end

--- Executes a given command asynchronously and returns the output
---@param cmd string # the command to execute
---@param args string[]|nil # the arguments to pass to the command
---@param ignore_codes integer[]|nil # the list of exit codes to ignore (default is 0)
---@param callback fun(stdout: string[]) # the callback to call when the command finishes
function M.async_cmd(cmd, args, ignore_codes, callback)
    ignore_codes = ignore_codes and utils.to_list(ignore_codes) or { 0 }

    async_cmd(cmd, args or {}, function(code, stdout, stderr)
        if not vim.tbl_contains(ignore_codes, code) then
            local message = type(code) == 'string' and code or string.format('no output, exit code: %d', code)
            if #stderr > 0 then
                message = utils.tbl_join(stderr, '\n') or ''
            elseif #stdout > 0 then
                message = utils.tbl_join(stdout, '\n') or ''
            end

            utils.error(string.format('Error grepping:\n\n ```%s```', message))
            return
        end

        callback(stdout)
    end)
end

---@class utils.GrepResult
---@field filename string # the name of the file
---@field lnum integer # the line number
---@field col integer # the column number
---@field text string # the text of the line

--- Greps a given term in a given directory
---@param term string # the term to grep for
---@param dir string|nil # the directory to grep in or the current directory if nil
---@param callback fun(results: utils.GrepResult[]) # the callback to call when the command finishes
function M.grep_dir(term, dir, callback)
    dir = dir or vim.loop.cwd()
    M.async_cmd('rg', { term, dir, '--vimgrep', '--no-heading', '--smart-case' }, { 0, 1 }, function(stdout)
        ---@type utils.GrepResult[]
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
    end)
end

--- Checks if a file is under git
---@param file_name string # the name of the file to check
---@return boolean # true if the file is under git, false otherwise
function M.file_is_under_git(file_name)
    assert(type(file_name) == 'string' and file_name ~= '')

    return M.cmd({ 'git', '-C', vim.fn.fnamemodify(file_name, ':p:h'), 'rev-parse' }, false) ~= nil
end
