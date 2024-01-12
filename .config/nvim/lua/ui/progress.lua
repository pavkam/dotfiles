local icons = require 'ui.icons'
local utils = require 'core.utils'

---@class utils.progress
local M = {}

---@class utils.progress.Task
---@field ctx any|nil # any context for the task
---@field ttl number # the time to live of the task in milliseconds
---@field prv boolean # whether the task is private (not reported globally)
---@field fn nil|fun(buffer: integer|nil): boolean # the function to check whether the task is still active

---@class utils.progress.TaskOptions
---@field ctx any|nil # any context for the task
---@field timeout number|nil # the timeout of the task in milliseconds
---@field prv boolean|nil # whether the task is private (not reported globally)
---@field fn nil|fun(buffer: integer|nil): boolean # the function to check whether the task is still active
---@field buffer integer|nil # the buffer to register the task for, or nil for global
--
---@type table<integer|"global", nil|table<string, utils.progress.Task>>
M.tasks = {}

--- Registers a task for progress tracking
---@param buffer integer|nil # the buffer to register the task for, or nil for global
---@param class string # the class of the task
---@param opts utils.progress.TaskOptions|nil # the options for the task
local function register_task(buffer, class, opts)
    assert(type(class) == 'string' and class ~= '')

    opts = opts or {}

    assert(type(opts.timeout) == 'number' or opts.timeout == nil)

    local key = buffer or 'global'

    local tasks = M.tasks[key]
    if not tasks then
        tasks = {}
    end

    local task = tasks[class]
    if task then
        task.ctx = opts.ctx
        task.ttl = opts.timeout or task.ttl
    else
        task = {
            ctx = opts.ctx,
            ttl = opts.timeout or 30000,
            prv = opts.prv,
            fn = opts.fn,
        }
    end

    tasks[class] = task
    M.tasks[key] = tasks
end

--- Unregisters a task for progress tracking
---@param buffer integer|nil # the buffer to unregister the task for, or nil for global
---@param class string # the class of the task
local function unregister_task(buffer, class)
    assert(type(class) == 'string' and class ~= '')

    local key = buffer or 'global'

    local tasks = M.tasks[key]
    if not tasks then
        return
    end

    tasks[class] = nil

    if #tasks == 0 then
        tasks = nil
    end

    M.tasks[key] = tasks
end

--- Updates the tasks' statuses
---@param interval integer # the interval since the last update in milliseconds
local function update_tasks(interval)
    local keys = vim.tbl_keys(M.tasks)

    for _, key in ipairs(keys) do
        local tasks = M.tasks[key]
        ---@cast tasks table<string, utils.progress.Task>

        local buffer = key ~= 'global' and key or nil
        if buffer and not vim.api.nvim_buf_is_valid(buffer) then
            M.tasks[key] = {}
        end

        local classes = vim.tbl_keys(tasks)

        for _, class in ipairs(classes) do
            local task = tasks[class]
            task.ttl = task.ttl and task.ttl - interval
            if not task.ttl or task.ttl <= 0 then
                utils.warn('Task "' .. class .. '" timed out!')
                tasks[class] = nil
            else
                if task.fn and not task.fn(buffer) then
                    tasks[class] = nil
                else
                    tasks[class] = task
                end
            end
        end

        if next(tasks) ~= nil then
            M.tasks[key] = tasks
        else
            M.tasks[key] = nil
        end
    end

    return next(M.tasks) ~= nil
end

---@type uv_timer_t|nil
local timer = nil

---@type integer|nil
local spinner_index = nil

local function ensure_polling()
    if next(M.tasks) == nil or timer then
        return
    end

    timer = vim.loop.new_timer()
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

            utils.trigger_status_update_event()
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
---@param opts utils.progress.TaskOptions|nil # the options for the task
function M.register_task(class, opts)
    opts = opts or {}

    if opts.buffer ~= nil then
        opts.buffer = opts.buffer or vim.api.nvim_get_current_buf()
    end

    register_task(opts.buffer, class, opts)
    ensure_polling()
end

--- Unregisters a task for progress tracking
---@param opts? { buffer?: integer } # optional modifiers
---@param class string # the class of the task
function M.unregister_task(class, opts)
    opts = opts or {}

    if opts.buffer ~= nil then
        opts.buffer = opts.buffer or vim.api.nvim_get_current_buf()
    end

    unregister_task(opts.buffer, class)
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

    local task = M.tasks[key] and M.tasks[key][class]
    if task then
        return spinner_icon(spinner_index or 0), task.ctx
    end

    return nil, nil
end

return M
