-- Provides functionality for asynchronous operations.
---@class sched
local M = {}

-- Delays a function call by a given time.
---@param fn fun(): any # the function to call.
---@param time integer # the time to wait in milliseconds.
function M.delay(fn, time)
    xassert {
        fn = { fn, 'callable' },
        time = { time, { 'integer', ['>'] = 0 } },
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
        interval = { interval, { 'integer', ['>'] = 0 } },
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
---@param fn fun(buffer: buffer, ...) # the function to call.
---@param wait integer # the wait time in milliseconds.
---@return fun(buffer: buffer, ...) # the debounced function.
function M.debounce(fn, wait)
    xassert {
        fn = { fn, 'callable' },
        wait = { wait, { 'integer', ['>'] = 0 } },
    }

    ---@type table<integer, uv_timer_t>
    local timers = {}

    ---@type fun(buffer: buffer, ...): any
    return function(buffer, ...)
        xassert {
            buffer = { buffer, 'table' },
        }

        local timer = timers[buffer.id]
        if not timer then
            timer = vim.uv.new_timer()
            timers[buffer.id] = timer
        else
            timer:stop()
        end

        local args = { ... }
        assert(timer:start(
            wait,
            0,
            vim.schedule_wrap(function()
                timer:stop()

                if vim.api.nvim_buf_is_valid(buffer.id) then
                    vim.api.nvim_buf_call(buffer.id, function()
                        fn(buffer, unpack(args))
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
                buffer_id = { 'integer', 'nil' },
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

    local reg_trace_back = ide.process.get_formatted_trace_back()
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
        buffer = opts.buffer_id,
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

---@class (exact) monitored_task # Tracks the progress of a task.
---@field name string # the name of the task.
---@field desc string # the description of the task.
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

-- Gets the description of a task.
---@param task monitored_task
local function task_description(task)
    return task.buffer
            and string.format(
                '`%s` in buffer `%s`',
                task.desc,
                task.buffer.file_path and ide.fs.base_name(task.buffer.file_path) or tostring(task.buffer.id)
            )
        or string.format('`%s`', task.desc)
end

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
            ide.tui.warn(
                string.format('Task %s is running for over `%d` seconds', task_description(task), task.timeout / 1000)
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
---@field desc string|nil # the description of the task.

-- Starts monitoring a task.
---@param name string # the name of the task to monitor.
---@param opts monitor_task_options|nil # the options.
---@return fun() # the done function.
function M.monitor_task(name, opts)
    ---@type monitor_task_options
    opts = table.merge(opts, {
        timeout = 60 * 1000,
        desc = name,
    })

    xassert {
        name = { name, { 'string', ['>'] = 0 } },
        opts = {
            opts,
            {
                timeout = { 'integer', ['>'] = 0 },
                buffer = { 'table', 'nil' },
                desc = { 'string', ['>'] = 0 },
            },
        },
    }

    local first_task = next(monitored_tasks) == nil

    local task
    for _, t in ipairs(monitored_tasks) do
        if
            t.name == name
            and (not t.buffer and not opts.buffer or t.buffer and opts.buffer and t.buffer.id == opts.buffer.id)
        then
            t.timeout = opts.timeout
            t.ttl = opts.timeout
            t.data = opts.data
            t.desc = opts.desc

            task = t
            break
        end
    end

    if not task then
        task = {
            name = name,
            desc = opts.desc,
            buffer = opts.buffer,
            timeout = opts.timeout,
            ttl = opts.timeout,
            data = opts.data,
            spent = 0,
        }

        table.insert(monitored_tasks, task)
    end

    if first_task then
        M.delay(trigger_tasks_update, update_interval)
    end

    return function()
        for i, t in ipairs(monitored_tasks) do
            if t.name == name then
                table.remove(monitored_tasks, i)
                break
            end
        end

        ide.tui.hint(string.format('Task %s completed in `%d` seconds', task_description(task), task.spent / 1000))
    end
end

-- Triggered when monitored tasks are updated (tick).
---@param callback fun(tasks: monitored_task[], tick: integer) # the callback to call.
function M.on_task_monitor_tick(callback)
    xassert {
        callback = { callback, 'callable' },
    }

    return subscribe_to_tasks_update(function()
        callback(monitored_tasks, monitored_tasks_tick)
    end)
end

return table.freeze(M)
