-- ProgressTracker: tracks running operations with spinners and timeout warnings.
-- Wraps task lifecycle (start/update/finish) with elapsed time tracking,
-- animated spinner frames, and configurable timeout detection.
--
-- Usage:
--   local id = IDE.progress:start('Formatting', { timeout = 5000 })
--   IDE.progress:update(id, 'Running prettier...')
--   IDE.progress:finish(id)
--
--   IDE.progress:on('tick', function()
--       for _, task in ipairs(IDE.progress:active()) do
--           print(task.spinner .. ' ' .. task.title)
--       end
--   end)

local EventEmitter = require 'ide.EventEmitter'
local Timer = require 'ide.Timer'

local ProgressTracker = Class('ProgressTracker')
Class.include(ProgressTracker, EventEmitter)

local SPINNER = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }

function ProgressTracker:init()
    self._tasks = {}  -- { id = { title, message, started_at, timeout, spinner_idx } }
    self._next_id = 1
    self._timer = nil
end

--- Start tracking a new task.
---@param title string
---@param opts? { timeout?: integer, message?: string }
---@return integer # task ID for updates/completion
function ProgressTracker:start(title, opts)
    opts = opts or {}
    local id = self._next_id
    self._next_id = id + 1

    self._tasks[id] = {
        title = title,
        message = opts.message or '',
        started_at = vim.uv.now(),
        timeout = opts.timeout or 30000,  -- 30s default
        spinner_idx = 0,
    }

    self:_ensure_timer()
    self:emit('start', id, self._tasks[id])
    return id
end

--- Update a task's message.
---@param id integer
---@param message string
function ProgressTracker:update(id, message)
    if self._tasks[id] then
        self._tasks[id].message = message
        self:emit('update', id, self._tasks[id])
    end
end

--- Complete a task.
---@param id integer
function ProgressTracker:finish(id)
    if self._tasks[id] then
        self._tasks[id] = nil
        self:emit('finish', id)
        if vim.tbl_isempty(self._tasks) then
            self:_stop_timer()
        end
    end
end

--- Get all active tasks.
---@return table[]
function ProgressTracker:active()
    local result = {}
    for id, task in pairs(self._tasks) do
        task.id = id
        task.elapsed = vim.uv.now() - task.started_at
        task.spinner = SPINNER[(task.spinner_idx % #SPINNER) + 1]
        task.timed_out = task.elapsed > task.timeout
        result[#result + 1] = task
    end
    return result
end

--- Check if any tasks are active.
---@return boolean
function ProgressTracker:is_busy()
    return not vim.tbl_isempty(self._tasks)
end

function ProgressTracker:_ensure_timer()
    if self._timer then return end
    self._timer = Timer.interval(100, function()
        for _, task in pairs(self._tasks) do
            task.spinner_idx = task.spinner_idx + 1
        end
        self:emit('tick')
    end, 'progress-spinner')
end

function ProgressTracker:_stop_timer()
    if self._timer then
        self._timer:stop()
        self._timer = nil
    end
end

---@return string
function ProgressTracker:__tostring()
    local count = 0
    for _ in pairs(self._tasks) do count = count + 1 end
    return string.format('ProgressTracker(tasks=%d)', count)
end

return ProgressTracker
