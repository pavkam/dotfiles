local icons = require 'ui.icons'

---@class utils.progress
local M = {}

---@class ui.progress.Task
---@field ctx any|nil # any context for the task
---@field ttl number # the time to live of the task in milliseconds
---@field timeout number # the timeout of the task in milliseconds
---@field prv boolean # whether the task is private (not reported globally)
---@field fn nil|fun(buffer: integer|nil): boolean # the function to check whether the task is still active

---@class ui.progress.TaskOptions
---@field ctx any|nil # any context for the task
---@field timeout number|nil # the timeout of the task in milliseconds
---@field prv boolean|nil # whether the task is private (not reported globally)
---@field fn nil|fun(buffer: integer|nil): boolean # the function to check whether the task is still active
---@field buffer integer|nil # the buffer to register the task for, or nil for global

---@alias ui.progress.TaskStatus table<string, ui.progress.Task>
---@alias ui.progress.TaskRegistry table<integer|"global", nil|ui.progress.TaskStatus>

---@type ui.progress.TaskRegistry
local tasks_by_owner = {}

--- Registers a task for progress tracking
---@param buffer integer|nil # the buffer to register the task for, or nil for global
---@param class string # the class of the task
---@param opts ui.progress.TaskOptions|nil # the options for the task
local function update(buffer, class, opts)
    assert(type(class) == 'string' and class ~= '')

    opts = opts or {}

    assert(type(opts.timeout) == 'number' or opts.timeout == nil)

    local key = buffer or 'global'

    local tasks = tasks_by_owner[key] or {}
    local task = tasks[class]

    if task then
        task.ctx = opts.ctx
        task.timeout = opts.timeout or task.timeout
        task.ttl = opts.timeout or task.ttl
        task.fn = task.fn or opts.fn
        task.prv = opts.prv or task.prv
    else
        local timeout = opts.timeout or (60 * 1000) -- one minute
        task = {
            ctx = opts.ctx,
            ttl = timeout,
            timeout = timeout,
            prv = opts.prv,
            fn = opts.fn,
        }
    end

    tasks[class] = task
    tasks_by_owner[key] = tasks
end

--- Un-registers a task for progress tracking
---@param buffer integer|nil # the buffer to un-register the task for, or nil for global
---@param class string # the class of the task
local function stop(buffer, class)
    assert(type(class) == 'string' and class ~= '')

    local key = buffer or 'global'

    local tasks = tasks_by_owner[key]
    if tasks then
        tasks[class] = nil
    end

    tasks_by_owner[key] = #tasks > 0 and tasks or nil
end

--- Updates the tasks' statuses
---@param interval integer # the interval since the last update in milliseconds
local function update_tasks(interval)
    local keys = vim.tbl_keys(tasks_by_owner)

    for _, key in ipairs(keys) do
        local buffer = key ~= 'global' and key or nil
        if buffer and not vim.api.nvim_buf_is_loaded(buffer) then
            tasks_by_owner[key] = {}
        end

        local tasks = tasks_by_owner[key] or {}
        local classes = vim.tbl_keys(tasks)

        for _, class in ipairs(classes) do
            local task = tasks[class]
            task.ttl = task.ttl - interval

            if task.ttl <= 0 then
                vim.warn('Task "' .. class .. '" is still running')
                tasks[class].ttl = tasks[class].timeout
            else
                if task.fn and not task.fn(buffer) then
                    vim.hint('Task "' .. class .. '" has finished')
                    tasks[class] = nil
                else
                    tasks[class] = task
                end
            end
        end

        if next(tasks) ~= nil then
            tasks_by_owner[key] = tasks
        else
            tasks_by_owner[key] = nil
        end
    end

    return next(tasks_by_owner) ~= nil
end

---@type uv_timer_t|nil
local timer = nil

---@type integer|nil
local spinner_index = nil

local function ensure_polling()
    if next(tasks_by_owner) == nil or timer then
        return
    end

    timer = vim.uv.new_timer()
    local interval = 100

    local res = timer:start(
        interval,
        interval,
        vim.schedule_wrap(function()
            local active_tasks = update_tasks(interval)
            if not active_tasks and timer then
                spinner_index = nil
                timer:stop()
                timer = nil
            else
                spinner_index = (spinner_index or 0) + 1
            end

            require('core.events').trigger_status_update_event()
        end)
    )

    assert(res == 0, 'Failed to start progress timer')
end

--- Gets the icon for a given level of progress
---@param index integer # the index of the icon to get
local function spinner_icon(index)
    assert(type(index) == 'number' and index >= 0)
    return icons.Progress[index % #icons.Progress + 1]
end

--- Registers a task for progress tracking
---@param class string # the class of the task
---@param opts ui.progress.TaskOptions|nil # the options for the task
function M.update(class, opts)
    opts = opts or {}

    if opts.buffer ~= nil then
        opts.buffer = opts.buffer or vim.api.nvim_get_current_buf()
    end

    update(opts.buffer, class, opts)
    ensure_polling()
end

--- Un-registers a task for progress tracking
---@param opts { buffer: integer | nil } | nil # optional modifiers
---@param class string # the class of the task
function M.stop(class, opts)
    opts = opts or {}

    if opts.buffer ~= nil then
        opts.buffer = opts.buffer or vim.api.nvim_get_current_buf()
    end

    stop(opts.buffer, class)
end

--- Gets the status for a given task class
---@param class string # the class of the task
---@param opts? { buffer?: integer } # optional modifiers
---@return string|nil, any|nil # the icon and the context of the task, or nil if there is no task with the given class
function M.status(class, opts)
    opts = opts or {}

    if opts.buffer ~= nil then
        opts.buffer = opts.buffer or vim.api.nvim_get_current_buf()
    end

    local key = opts.buffer or 'global'

    local task = tasks_by_owner[key] and tasks_by_owner[key][class]
    if task then
        return spinner_icon(spinner_index or 0), task.ctx
    end

    return nil, nil
end

--- Returns the current snapshot of the tasks
---@return ui.progress.TaskRegistry
function M.snapshot()
    return vim.deepcopy(tasks_by_owner)
end

return M
