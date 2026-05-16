-- Timer: periodic and delayed execution abstraction.
-- Wraps vim.uv timers into a clean API.
--
-- Usage:
--   local t = Timer.interval(1000, function() print('tick') end)
--   t:stop()
--
--   Timer.delay(500, function() print('delayed') end)

local Timer = Class('Timer')

---@param handle uv_timer_t
---@param desc string|nil
function Timer:init(handle, desc)
    self._handle = handle
    self._desc = desc or 'timer'
    self._active = true
end

--- Stop the timer.
function Timer:stop()
    if self._active and self._handle then
        self._handle:stop()
        self._active = false
    end
end

--- Whether the timer is still running.
---@return boolean
function Timer:is_active()
    return self._active
end

---@return string
function Timer:__tostring()
    return string.format('Timer(%s, %s)', self._desc, self._active and 'active' or 'stopped')
end

-- Class methods

--- Defer a function to the next event loop iteration.
---@param fn function
function Timer.defer(fn)
    vim.schedule(fn)
end


--- Create a repeating timer.
---@param interval_ms integer
---@param fn function
---@param desc string|nil
---@return Timer
function Timer.interval(interval_ms, fn, desc)
    local handle = vim.uv.new_timer()
    handle:start(interval_ms, interval_ms, vim.schedule_wrap(fn))
    return Timer(handle, desc)
end

--- Create a one-shot delayed timer.
---@param delay_ms integer
---@param fn function
---@param desc string|nil
---@return Timer
function Timer.delay(delay_ms, fn, desc)
    local handle = vim.uv.new_timer()
    local timer
    handle:start(delay_ms, 0, vim.schedule_wrap(function()
        fn()
        if timer then timer._active = false end
        handle:stop()
    end))
    timer = Timer(handle, desc)
    return timer
end

--- Create a debounced function.
---@param wait_ms integer
---@param fn function
---@return function # debounced function
function Timer.debounce(wait_ms, fn)
    local handle = vim.uv.new_timer()
    return function(...)
        local args = { ... }
        handle:stop()
        handle:start(wait_ms, 0, vim.schedule_wrap(function()
            handle:stop()
            fn(unpack(args))
        end))
    end
end

return Timer
