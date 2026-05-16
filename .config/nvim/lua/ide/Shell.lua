-- Shell: async command execution abstraction.
-- Wraps vim.system() into a clean API with cancellation, streaming, and process lifecycle.

local Shell = Class('Shell')

function Shell:init() end

--- A handle to a running process.
---@class ProcessHandle
---@field kill fun() # kill the process
---@field wait fun(timeout?: integer): { code: integer, stdout: string, stderr: string } # block until done
---@field is_running fun(): boolean

--- Run a command asynchronously and call back with the result.
---@param cmd string
---@param args string[]
---@param opts { cwd?: string, stdin?: string, env?: table }|nil
---@param callback fun(result: { code: integer, stdout: string, stderr: string })
---@return ProcessHandle
function Shell:run(cmd, args, opts, callback)
    opts = opts or {}
    local full_cmd = vim.list_extend({ cmd }, args)

    local done = false
    local proc = vim.system(full_cmd, {
        text = true,
        cwd = opts.cwd,
        stdin = opts.stdin,
        env = opts.env,
    }, vim.schedule_wrap(function(result)
        done = true
        if callback then
            callback {
                code = result.code,
                stdout = result.stdout or '',
                stderr = result.stderr or '',
            }
        end
    end))

    return {
        kill = function() pcall(proc.kill, proc) end,
        wait = function(timeout)
            local r = proc:wait(timeout or 10000)
            done = true
            return { code = r.code, stdout = r.stdout or '', stderr = r.stderr or '' }
        end,
        is_running = function() return not done end,
    }
end

--- Run a command synchronously and return the result.
---@param cmd string
---@param args string[]
---@param opts { cwd?: string, stdin?: string, timeout?: integer, env?: table }|nil
---@return { code: integer, stdout: string, stderr: string }
function Shell:run_sync(cmd, args, opts)
    opts = opts or {}
    local full_cmd = vim.list_extend({ cmd }, args)

    local result = vim.system(full_cmd, {
        text = true,
        cwd = opts.cwd,
        stdin = opts.stdin,
        env = opts.env,
    }):wait(opts.timeout or 10000)

    return {
        code = result.code,
        stdout = result.stdout or '',
        stderr = result.stderr or '',
    }
end

--- Run a command with line-by-line stdout streaming.
--- Calls on_line for each line of stdout as it arrives.
--- Calls on_exit when the process finishes.
---@param cmd string
---@param args string[]
---@param opts { cwd?: string, stdin?: string, env?: table }|nil
---@param callbacks { on_line?: fun(line: string), on_exit?: fun(code: integer) }
---@return ProcessHandle
function Shell:run_streaming(cmd, args, opts, callbacks)
    opts = opts or {}
    callbacks = callbacks or {}
    local full_cmd = vim.list_extend({ cmd }, args)
    local partial = ''
    local done = false

    local proc = vim.system(full_cmd, {
        text = true,
        cwd = opts.cwd,
        stdin = opts.stdin,
        env = opts.env,
        stdout = function(_, data)
            if not data then return end
            partial = partial .. data
            while true do
                local nl = partial:find('\n')
                if not nl then break end
                local line = partial:sub(1, nl - 1)
                partial = partial:sub(nl + 1)
                if callbacks.on_line then
                    vim.schedule(function() callbacks.on_line(line) end)
                end
            end
        end,
    }, vim.schedule_wrap(function(result)
        done = true
        if partial ~= '' and callbacks.on_line then
            callbacks.on_line(partial)
            partial = ''
        end
        if callbacks.on_exit then
            callbacks.on_exit(result.code)
        end
    end))

    return {
        kill = function() pcall(proc.kill, proc) end,
        wait = function(timeout)
            local r = proc:wait(timeout or 10000)
            done = true
            return { code = r.code, stdout = r.stdout or '', stderr = r.stderr or '' }
        end,
        is_running = function() return not done end,
    }
end

--- Check if a command exists in PATH.
---@param cmd string
---@return boolean
function Shell:has(cmd)
    return vim.fn.executable(cmd) == 1
end

--- Get the full path to an executable, or nil if not found.
---@param cmd string
---@return string|nil
function Shell:exepath(cmd)
    local path = vim.fn.exepath(cmd)
    return path ~= '' and path or nil
end

--- Open a floating terminal with a command.
---@param cmd string
---@param opts { cwd?: string }|nil
function Shell:floating(cmd, opts)
    opts = opts or {}
    local buf = vim.api.nvim_create_buf(false, true)
    local width = math.floor(vim.o.columns * 0.9)
    local height = math.floor(vim.o.lines * 0.85)
    local win = vim.api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        col = math.floor((vim.o.columns - width) / 2),
        row = math.floor((vim.o.lines - height) / 2),
        style = 'minimal',
        border = vim.g.border_style or 'rounded',
    })
    vim.fn.jobstart(cmd, { term = true, cwd = opts.cwd or vim.uv.cwd() })
    vim.cmd.startinsert()

    vim.api.nvim_create_autocmd('BufLeave', {
        buffer = buf,
        once = true,
        callback = function()
            if vim.api.nvim_win_is_valid(win) then
                vim.api.nvim_win_close(win, true)
            end
        end,
    })
end

---@return string
function Shell:__tostring()
    return 'Shell()'
end

return Shell
