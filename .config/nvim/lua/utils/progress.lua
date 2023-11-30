local icons = require 'utils.icons'
local utils = require 'utils'

---@class utils.progress
local M = {}

---@class utils.progress.Task
---@field desc string|nil # the description of the task
---@field ttl number # the time to live of the task in milliseconds
---@field prv boolean # whether the task is private (not reported globally)
---@field fn nil|fun(buffer: integer|nil): boolean # the function to check whether the task is still active

---@class utils.progress.TaskOptions
---@field desc string|nil # the description of the task
---@field timeout number|nil # the timeout of the task in milliseconds
---@field prv boolean|nil # whether the task is private (not reported globally)
---@field fn nil|fun(buffer: integer|nil): boolean # the function to check whether the task is still active

---@type table<integer|"global", nil|table<string, utils.progress.Task>>
M.tasks = {}

--- Registers a task for progress tracking
---@param buffer integer|nil # the buffer to register the task for, or nil for global
---@param class string # the class of the task
---@param opts utils.progress.TaskOptions|nil # the options for the task
local function register_task(buffer, class, opts)
    assert(type(class) == 'string' and class ~= '')

    opts = opts or {}

    assert(type(opts.desc) == 'string' or opts.desc == nil)
    assert(type(opts.timeout) == 'number' or opts.timeout == nil)

    local key = buffer or 'global'

    local tasks = M.tasks[key]
    if not tasks then
        tasks = {}
    end

    local task = tasks[class]
    if task then
        task.desc = opts.desc
        task.ttl = opts.timeout
    else
        task = {
            desc = opts.desc,
            ttl = opts.timeout or 10000,
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
            if task.ttl <= 0 then
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
            if not active_tasks then
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
---@param buffer integer|nil # the buffer to register the task for, or nil or 0 for current buffer
---@param class string # the class of the task
---@param opts utils.progress.TaskOptions|nil # the options for the task
function M.register_task_for_buffer(buffer, class, opts)
    buffer = buffer or vim.api.nvim_get_current_buf()
    register_task(buffer, class, opts)
    ensure_polling()
end

--- Registers a task for progress tracking
---@param class string # the class of the task
---@param opts utils.progress.TaskOptions|nil # the options for the task
function M.register_task(class, opts)
    register_task(nil, class, opts)
    ensure_polling()
end

--- Unregisters a task for progress tracking
---@param buffer integer|nil # the buffer to unregister the task for, or nil or 0 for current buffer
---@param class string # the class of the task
function M.unregister_task_for_buffer(buffer, class)
    buffer = buffer or vim.api.nvim_get_current_buf()
    unregister_task(buffer, class)
end

--- Unregisters a task for progress tracking
---@param class string # the class of the task
function M.unregister_task(class)
    unregister_task(nil, class)
end

function M.spinner_for_buffer(buffer, class)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local task = M.tasks[buffer] and M.tasks[buffer][class]
    return task and spinner_icon(spinner_index or 0)
end

function M.spinner(class)
    local task = M.tasks['global'] and M.tasks['global'][class]
    return task and spinner_icon(spinner_index or 0)
end

return M
