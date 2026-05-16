-- Reactive event system mixin.
-- Any class can include this to get on/off/emit capabilities.
-- Events are typed strings; handlers receive arbitrary arguments.
--
-- Usage:
--   Class.include(MyClass, require('ide.EventEmitter'))
--   local obj = MyClass()
--   obj:on('change', function(data) print(data) end)
--   obj:emit('change', { line = 42 })

---@class EventEmitterMixin
local EventEmitter = {}

--- Subscribe to an event.
---@param event string
---@param fn function
---@return function # unsubscribe function
function EventEmitter:on(event, fn)
    self._events = self._events or {}
    self._events[event] = self._events[event] or {}
    table.insert(self._events[event], fn)

    return function()
        self:off(event, fn)
    end
end

--- Subscribe to an event, fire once then auto-unsubscribe.
---@param event string
---@param fn function
---@return function # unsubscribe function
function EventEmitter:once(event, fn)
    local unsub
    unsub = self:on(event, function(...)
        unsub()
        fn(...)
    end)
    return unsub
end

--- Unsubscribe from an event.
---@param event string
---@param fn function
function EventEmitter:off(event, fn)
    if not self._events or not self._events[event] then
        return
    end
    for i, handler in ipairs(self._events[event]) do
        if handler == fn then
            table.remove(self._events[event], i)
            return
        end
    end
end

--- Emit an event to all subscribers.
--- Set _suppress_errors = true to silence error notifications (for testing).
---@param event string
---@param ... any
function EventEmitter:emit(event, ...)
    if not self._events or not self._events[event] then
        return
    end
    local src = self._events[event]
    local handlers = {}
    for i = 1, #src do handlers[i] = src[i] end
    for _, fn in ipairs(handlers) do
        local ok, err = pcall(fn, ...)
        if not ok and not self._suppress_errors then
            vim.schedule(function()
                vim.notify(
                    string.format('[IDE] Event %q handler error: %s', event, err),
                    vim.log.levels.ERROR
                )
            end)
        end
    end
end

--- Remove all handlers, or all handlers for a specific event.
---@param event? string
function EventEmitter:clear(event)
    if not self._events then return end
    if event then
        self._events[event] = nil
    else
        self._events = {}
    end
end

--- Check if any handlers are subscribed to an event.
---@param event string
---@return boolean
function EventEmitter:has_listeners(event)
    return self._events ~= nil
        and self._events[event] ~= nil
        and #self._events[event] > 0
end

return EventEmitter
