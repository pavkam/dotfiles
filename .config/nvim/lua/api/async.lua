-- Provides functionality for asynchronous operations.
---@class async
local M = {}

--- Polls a function until it returns a "falsy" value.
---@param fn fun(...): any # the function to call.
---@param interval integer # the interval in milliseconds.
---@return fun() # the stop function.
function M.poll(fn, interval, ...)
    xassert {
        fn = { fn, 'callable' },
        interval = { interval, { 'number', ['>'] = 0 } },
    }

    local timer = vim.uv.new_timer()
    local args = { ... }

    assert(
        timer:start(
            0,
            interval,
            vim.schedule_wrap(function()
                if not fn(unpack(args)) then
                    timer:stop()
                end
            end)
        ),
        'failed to start timer'
    )

    return function()
        timer:stop()
    end
end

--- Defers a function call (per buffer) in LIFO mode.
--- If the function is called again before the timeout,
--- the timer is reset.
---@param fn fun(buffer_id: integer, ...) # the function to call.
---@param wait integer # the wait time in milliseconds.
---@return fun(buffer: integer, ...) # the debounced function.
function M.debounce(fn, wait)
    xassert {
        fn = { fn, 'callable' },
        wait = { wait, { 'integer', ['>'] = 0 } },
    }

    ---@type table<integer, uv_timer_t>
    local timers = {}

    ---@type fun(buffer_id: integer|nil, ...): any
    return function(buffer_id, ...)
        xassert {
            buffer_id = { buffer_id, { 'integer', ['>'] = -1 }, true },
        }

        buffer_id = buffer_id or vim.api.nvim_get_current_buf()

        assert(vim.api.nvim_buf_is_valid(buffer_id)) --TODO: use the buf

        local timer = timers[buffer_id]
        if not timer then
            timer = vim.uv.new_timer()
            timers[buffer_id] = timer
        else
            timer:stop()
        end

        local args = { ... }
        assert(timer:start(
            wait,
            0,
            vim.schedule_wrap(function()
                timer:stop()

                if vim.api.nvim_buf_is_valid(buffer_id) then
                    vim.api.nvim_buf_call(buffer_id, function()
                        fn(buffer_id, unpack(args))
                    end)
                end
            end)
        ))
    end
end

---@class (exact) async_tracked_task # Tracks the progress of a task.
---@field name string # the name of the task.
---@field buffer buffer|nil # the buffer to track the task for.
---@field spent integer # the time spent on the task in milliseconds.
---@field ttl integer # the time to live of the task in milliseconds.
---@field timeout integer # the timeout of the task in milliseconds.
---@field data any|nil # custom data for the task.
---@field check_fn fun(data: any): boolean # the function checking the task.
---@field update fun(fn: fun(data: any|nil): any|nil): async_tracked_task # updates the task with new data.

---@type table<async_tracked_task, boolean>
local tracking_tasks = {}

--- Updates the tasks' statuses.
---@param interval integer # the interval since the last update in milliseconds.
local function update_tracked_tasks(interval)
    local remaining_tasks = {}

    for tracked_task, _ in pairs(tracking_tasks) do
        tracked_task.ttl = tracked_task.ttl - interval
        tracked_task.spent = tracked_task.spent + interval

        if tracked_task.ttl <= 0 then
            require('api.tui').warn(string.format('Task `%s` is still running', tracked_task.name))

            tracked_task.ttl = tracked_task.timeout
            remaining_tasks[tracked_task] = true
        elseif tracked_task.check_fn(tracked_task.data) then
            remaining_tasks[tracked_task] = true
        end
    end

    tracking_tasks = remaining_tasks
    return next(tracking_tasks) ~= nil
end

local event_pattern = 'TasksRunning'

---@type uv_timer_t|nil
local tracking_timer = nil

---@type integer|nil
local tracking_tick = nil

-- Updates the tasks' statuses.
local function ensure_polling()
    if next(tracking_tasks) == nil or tracking_timer then
        return
    end

    tracking_timer = vim.uv.new_timer()
    local interval = 100

    assert(
        tracking_timer:start(
            interval,
            interval,
            vim.schedule_wrap(function()
                local tasks_remaining = update_tracked_tasks(interval)
                if not tasks_remaining and tracking_timer then
                    tracking_tick = nil
                    tracking_timer:stop()
                    tracking_timer = nil
                else
                    tracking_tick = (tracking_tick or 0) + 1
                end

                if package.loaded['lualine'] then
                    local refresh = require('lualine').refresh --[[@as function]]
                    pcall(refresh)
                else
                    vim.cmd.redrawstatus()
                end

                vim.api.nvim_exec_autocmds('User', {
                    pattern = event_pattern,
                    modeline = false,
                })
            end)
        ),
        'failed to start progress timer'
    )
end

---@class (exact) async_tracked_task_options # The options for tracking a task.
---@field check_fn nil|fun(data: any): boolean # the function to call.
---@field timeout nil|integer # the timeout of the task in milliseconds.
---@field buffer nil|buffer # the buffer to track the task for.

-- Creates a new task tracker.
---@param name string # the name of the task to track.
---@param opts async_tracked_task_options|nil # the options for the tracker.
---@return async_tracked_task # the tracker.
function M.track_task(name, opts)
    ---@type async_tracked_task_options
    opts = table.merge(opts, {
        check_fn = function()
            return true
        end,
        timeout = 60 * 1000,
        global = true,
    })

    xassert {
        name = { name, { 'string', ['>'] = 0 } },
        opts = {
            opts,
            {
                global = { 'boolean' },
                check_fn = 'callable',
                timeout = { 'integer', ['>'] = 0 },
                buffer = { 'table', 'nil' },
            },
        },
    }

    local already_in = table.any(tracking_tasks, function(task)
        local task_buffer_id = task.buffer and task.buffer.id
        local opts_buffer_id = opts.buffer and opts.buffer.id

        return task.name == name and task_buffer_id == opts_buffer_id
    end)

    if already_in then
        error(
            string.format(
                'task `%s` is already being tracked for `%s`.',
                name,
                opts.buffer and opts.buffer.id or 'global'
            )
        )
    end

    local task = {
        spent = 0,
        buffer = opts.buffer,
        timeout = opts.timeout,
        ttl = opts.timeout,
        check_fn = opts.check_fn,
        name = name,
    }

    ---@param fn fun(data: any|nil): any|nil
    task.update = function(fn)
        xassert {
            fn = { fn, 'callable' },
        }

        local orig_data = task.data
        local new_data = fn(orig_data)

        if new_data == orig_data then
            new_data = table.clone(new_data)
        end

        task.data = new_data
        task.ttl = task.timeout

        if new_data and task.check_fn(new_data) then
            tracking_tasks[task] = true
            ensure_polling()
        else
            tracking_tasks[task] = nil
        end

        return task
    end

    ---@type async_tracked_task
    return table.freeze(task)
end

local auto_group = vim.api.nvim_create_augroup('async.active_tasks_tracking', { clear = false })

-- Creates a function that opdates a value based on the status of a task.
---@generic T, O
---@param name string # the name of the task to track.
---@param fn fun(data: T|nil, tick: integer): O|nil # the function to call.
---@return fun(): O|nil # the result of the function.
function M.bind_to_task(name, fn)
    xassert {
        name = { name, { 'string', ['>'] = 0 } },
        fn = { fn, 'callable' },
    }

    local result

    vim.api.nvim_create_autocmd('User', {
        group = auto_group,
        callback = function()
            local task = nil
            for t, _ in pairs(tracking_tasks) do
                if not t.buffer and t.name == name then
                    task = t
                    break
                end
            end

            if not task then
                return
            end

            if task and task.data then
                result = fn(task.data, tracking_tick or 1)
            end
        end,
        pattern = event_pattern,
    })

    return function()
        return result
    end
end

-- Creates a function that opdates a value based on the status of a task.
---@generic T, O
---@param name string # the name of the task to track.
---@param fn fun(buffer: buffer, data: T|nil, tick: integer): O|nil # the function to call.
---@return fun(): O|nil # the result of the function.
function M.bind_to_buffer_task(name, fn)
    xassert {
        name = { name, { 'string', ['>'] = 0 } },
        fn = { fn, 'callable' },
    }

    ---@type table<integer, { data: any, last: boolean }>
    local results = {}

    local buffers = require 'api.buf'

    vim.api.nvim_create_autocmd('User', {
        group = auto_group,
        callback = function(evt)
            local buffer = buffers[evt.buf]
            local task = nil
            for t, _ in pairs(tracking_tasks) do
                if t.buffer and buffer.id == t.buffer.id and t.name == name then
                    task = t
                    break
                end
            end

            if (not task or not task.data) and (not results[buffer.id] or results[buffer.id].last) then
                results[buffer.id] = { data = fn(buffer, nil, tracking_tick or 1), last = false }
            elseif task and task.data then
                results[buffer.id] = { data = fn(buffer, task.data, tracking_tick or 1), last = true }
            end
        end,
        pattern = event_pattern,
    })

    return function()
        local res = results[buffers.current.id]
        if not res then
            res = { data = fn(buffers.current, nil, tracking_tick or 1), last = false }
        end
        return res and res.data
    end
end

return table.freeze(M)
