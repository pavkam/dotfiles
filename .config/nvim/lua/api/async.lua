-- Provides functionality for asynchronous operations.
---@class async
local M = {}

-- Delays a function call by a given time.
---@param fn fun(): any # the function to call.
---@param time integer # the time to wait in milliseconds.
function M.delay(fn, time)
    xassert {
        fn = { fn, 'callable' },
        time = { time, { 'number', ['>'] = 0 } },
    }

    vim.defer_fn(fn, time)
end

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

---@class (exact) subscribe_events_options # The options for the auto command.
---@field buffer integer|nil # the buffer to target (or `nil` for all buffers).
---@field description string|nil # the description of the auto command.
---@field group string|nil # the group of the auto command.
---@field clear boolean|nil # whether to clear the group before creating it.
---@field once boolean|nil # whether to only trigger once.
---@field patterns string|string[]|nil # the pattern to target (or `nil` for all patterns).

---@class (exact) vim.auto_command_event_arguments # The event args received by the auto command.
---@field id integer # the id of the auto command.
---@field event string # the event that was triggered.
---@field buf integer|nil # the buffer the event was triggered on (or `nil` of no buffer).
---@field data table|nil # the data of the auto command.
---@field group integer|nil # the group of the auto command.
---@field match string|nil # the match of the auto command.

-- Subscribes to events.
---@param events string|string[] # the list of events to trigger on.
---@param handler fun(args: vim.auto_command_event_arguments) # the handler for the event.
---@param opts subscribe_events_options|nil # the options for the auto command.
---@return fun() # the deregister function.
function M.subscribe_event(events, handler, opts)
    opts = table.merge(opts, {
        clear = false,
        once = false,
    })

    xassert {
        events = {
            events,
            {
                { 'string', ['>'] = 0 },
                { ['*'] = { 'string', ['>'] = 0 } },
            },
        },
        handler = { handler, 'callable' },
        opts = {
            opts,
            {
                buffer = { 'number', 'nil' },
                description = { nil, { 'string', ['>'] = 0 } },
                group = { nil, { 'string', ['>'] = 0 } },
                patterns = {
                    'nil',
                    { 'string', ['>'] = 0 },
                    { 'list', ['*'] = { 'string', ['>'] = 0 } },
                },
                clear = { 'boolean' },
                once = { 'boolean' },
            },
        },
    }

    local reg_trace_back = require('api.process').get_formatted_trace_back(4)
    local auto_group_id = opts.group and vim.api.nvim_create_augroup(opts.group, { clear = opts.clear or false }) or nil

    local real_events = {}
    local real_patterns = {}
    for _, event in ipairs(table.to_list(events)) do --[[@cast event string]]
        if event:starts_with '@' then
            real_patterns[event:sub(2)] = true
            real_events['User'] = true
        else
            real_events[event] = true
        end
    end

    events = table.keys(real_events)
    opts.patterns = table.list_merge(opts.patterns, table.keys(real_patterns))

    ---@type vim.api.keyset.create_autocmd
    local auto_command_opts = {
        callback = function(args)
            local ok, err = pcall(handler, args)

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
        once = opts.once,
        nested = false,
    }

    -- create auto command
    local id = vim.api.nvim_create_autocmd(events, auto_command_opts)

    return function()
        vim.api.nvim_del_autocmd(id)
    end
end

---@class (exact) define_events_options # The options for the auto command.
---@field description string|nil # the description of the auto command.
---@field group string|nil # the group of the auto command.

---@alias define_event_subscribe_function
---|fun(handler: fun(args: vim.auto_command_event_arguments), opts: subscribe_events_options|nil): fun()

-- Defines a new event.
---@param name string # the name of the event.
---@return define_event_subscribe_function, fun(data: any)
function M.define_event(name)
    xassert {
        name = { name, { 'string', ['>'] = 0 } },
    }

    local subscribe = function(handler, opts)
        return M.subscribe_event(
            string.format('@%s', name),
            handler,
            opts and { group = opts.group, description = opts.description }
        )
    end

    local trigger = function(data)
        vim.api.nvim_exec_autocmds('User', {
            pattern = name,
            modeline = false,
            data = data,
        })
    end

    return subscribe, trigger
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

---@class (exact) monitored_task # Tracks the progress of a task.
---@field name string # the name of the task.
---@field buffer buffer|nil # the buffer to track the task for.
---@field data any|nil # custom data for the task.
---@field spent integer # the time spent on the task in milliseconds.
---@field ttl integer # the time to live of the task in milliseconds.
---@field timeout integer # the timeout of the task in milliseconds.

---@type monitored_task[]
local monitored_tasks = {}

local monitored_tasks_tick = 0
local update_interval = 100
local subscribe_to_tasks_update, trigger_tasks_update = M.define_event 'TasksRunning'

subscribe_to_tasks_update(function()
    if next(monitored_tasks) == nil then
        monitored_tasks_tick = 0
        return
    end

    monitored_tasks_tick = monitored_tasks_tick + 1

    for _, task in pairs(monitored_tasks) do
        task.ttl = task.ttl - update_interval
        task.spent = task.spent + update_interval

        if task.ttl <= 0 then
            local task_str = task.buffer and string.format('`%s` in buffer `%s`', task.name, task.buffer.id)
                or string.format('`%s`', task.name)

            require('api.tui').warn(
                string.format('Task %s is running for over `%d` seconds', task_str, task.timeout / 1000)
            )

            task.ttl = task.timeout
        end
    end

    M.delay(trigger_tasks_update, update_interval)
end, {
    description = 'Updates the listeners for monitored tasks',
    group = 'async.monitored_tasks',
})

---@class (exact) monitor_task_options # The options for monitoring a task.
---@field timeout nil|integer # the timeout of the task in milliseconds (default: 60 seconds).
---@field buffer nil|buffer # the buffer to track the task for.
---@field data any|nil # the data for the task.

-- Starts monitoring a task.
---@param name string # the name of the task to monitor.
---@param opts monitor_task_options|nil # the options.
---@return fun() # the done function.
function M.monitor_task(name, opts)
    ---@type monitor_task_options
    opts = table.merge(opts, {
        timeout = 60 * 1000,
    })

    xassert {
        name = { name, { 'string', ['>'] = 0 } },
        opts = {
            opts,
            {
                timeout = { 'integer', ['>'] = 0 },
                buffer = { 'table', 'nil' },
            },
        },
    }

    local task
    for _, t in ipairs(monitored_tasks) do
        if
            t.name == name
            and (not t.buffer and not opts.buffer or t.buffer and opts.buffer and t.buffer.id == opts.buffer.id)
        then
            t.timeout = opts.timeout
            t.ttl = opts.timeout
            t.data = opts.data

            task = t
            break
        end
    end

    if not task then
        task = {
            name = name,
            buffer = opts.buffer,
            timeout = opts.timeout,
            ttl = opts.timeout,
            data = opts.data,
            spent = 0,
        }

        table.insert(monitored_tasks, task)
    end

    M.delay(trigger_tasks_update, update_interval)

    return function()
        for i, t in ipairs(monitored_tasks) do
            if t.name == name then
                table.remove(monitored_tasks, i)
                break
            end
        end
    end
end

---@class (exact) monitored_task_update # The callback for monitored task updates.
---@field task monitored_task # the task being updated.
---@field buffer buffer|nil # the buffer the task is being updated for.
---@field tick integer # the current tick.

-- Triggered when a monitored tasks are updated (tick)
---@param name string # the name of the task to monitor.
---@param buffer buffer|nil # the buffer to track the task for.
---@param callback fun(data: monitored_task_update) # the callback to call.
function M.on_monitored_task_update(name, buffer, callback)
    xassert {
        name = { name, { 'string', ['>'] = 0 } },
        callback = { callback, 'callable' },
        buffer = { buffer, { 'table', 'nil' } },
    }

    return M.subscribe_event(event_pattern, function()
        for _, task in ipairs(monitored_tasks) do
            if task.name == name and (not buffer or task.buffer and task.buffer.id == buffer.id) then
                callback { task = task, tick = monitored_tasks_tick, buffer = task.buffer }
            end
        end
    end)
end

return table.freeze(M)
