-- Notify: notification abstraction.
-- Routes notifications through the owned Notifications extension when available,
-- falling back to vim.notify (which may be nvim-notify or Neovim default).

local Notify = Class('Notify')

local MAX_HISTORY = 100

function Notify:init()
    self._extension = nil
    self._history = {}
end

---@param msg string
---@param level integer
---@param opts { title?: string }|nil
local function send(self_ref, msg, level, opts)
    opts = opts or {}
    self_ref:_record(msg, level, opts)

    local ext = self_ref._extension
    if not ext then
        local ok, notifications = pcall(function() return IDE:extension('Notifications') end)
        if ok and notifications then
            self_ref._extension = notifications
            ext = notifications
        end
    end

    if ext then
        if vim.in_fast_event() then
            vim.schedule(function() ext:show(msg, level, opts) end)
        else
            ext:show(msg, level, opts)
        end
        return
    end

    if vim.in_fast_event() then
        vim.notify(msg, level, { title = opts.title or 'IDE' })
        return
    end
    vim.schedule(function()
        vim.notify(msg, level, { title = opts.title or 'IDE' })
    end)
end

---@param msg string
---@param opts { title?: string }|nil
function Notify:info(msg, opts) send(self, msg, vim.log.levels.INFO, opts) end

---@param msg string
---@param opts { title?: string }|nil
function Notify:warn(msg, opts) send(self, msg, vim.log.levels.WARN, opts) end

---@param msg string
---@param opts { title?: string }|nil
function Notify:error(msg, opts) send(self, msg, vim.log.levels.ERROR, opts) end

---@param msg string
---@param opts { title?: string }|nil
function Notify:debug(msg, opts) send(self, msg, vim.log.levels.DEBUG, opts) end

--- Record a notification in the history ring buffer.
---@param msg string
---@param level integer
---@param opts { title?: string }|nil
function Notify:_record(msg, level, opts)
    table.insert(self._history, 1, {
        level = level,
        message = msg,
        title = opts and opts.title or nil,
        timestamp = os.time(),
    })
    if #self._history > MAX_HISTORY then
        self._history[#self._history] = nil
    end
end

--- Return the notification history (most recent first).
---@return { level: integer, message: string, title?: string, timestamp: integer }[]
function Notify:history()
    return self._history
end

--- Clear the notification history.
function Notify:clear_history()
    self._history = {}
end

--- Show a progress notification that can be updated.
--- Returns a handle with :update(msg, pct) and :finish(msg) methods.
---@param msg string # initial message
---@param opts? { title?: string }
---@return { update: fun(self, msg: string, pct?: number), finish: fun(self, msg?: string) }
function Notify:progress(msg, opts)
    opts = opts or {}
    local handle = {
        _msg = msg,
        _pct = 0,
        _done = false,
        _notify = self,
        _title = opts.title,
    }

    function handle:update(new_msg, pct)
        if self._done then return end
        self._msg = new_msg
        self._pct = pct or self._pct
        local display = new_msg
        if pct then
            display = string.format('%s (%d%%)', new_msg, math.floor(pct * 100))
        end
        self._notify:info(display, { title = self._title })
    end

    function handle:finish(final_msg)
        if self._done then return end
        self._done = true
        self._pct = 1
        if final_msg then
            self._notify:info(final_msg, { title = self._title })
        end
    end

    -- Show initial message
    self:info(msg, opts)

    return handle
end

---@return string
function Notify:__tostring() return 'Notify()' end

return Notify
