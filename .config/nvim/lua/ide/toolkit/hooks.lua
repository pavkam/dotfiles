-- hooks.lua: React-like hooks for function components.
-- Provides useState, useMemo, useCallback, useEffect for declarative UI.
--
-- Usage:
--   local h = require('ide.toolkit.hooks')
--   local function MyComponent(props)
--     local count, setCount = h.useState(0)
--     local doubled = h.useMemo(function() return count * 2 end, { count })
--     h.useEffect(function()
--       print('count changed to', count)
--       return function() print('cleanup') end
--     end, { count })
--     return { type = 'text', text = tostring(doubled) }
--   end

local M = {}

-- Internal state: current component context during render
local _current_ctx = nil
local _hook_index = 0
local _batching = false
local _batch_queue = {}

---@class HookContext
---@field hooks table[] # array of hook states
---@field effects { fn: function, deps: any[], cleanup?: function }[]
---@field dirty boolean # whether the component needs re-render
---@field render_fn function # the component function
---@field props table # current props
---@field on_dirty function|nil # callback when state changes

--- Begin a render cycle for a component.
---@param ctx HookContext
function M.begin_render(ctx)
    _current_ctx = ctx
    _hook_index = 0
end

--- End the render cycle.
function M.end_render()
    _current_ctx = nil
    _hook_index = 0
end

--- Create a new hook context for a function component.
---@param render_fn function
---@param props table
---@param on_dirty function|nil # called when state changes trigger re-render
---@return HookContext
function M.create_context(render_fn, props, on_dirty)
    return {
        hooks = {},
        effects = {},
        dirty = true,
        render_fn = render_fn,
        props = props,
        on_dirty = on_dirty,
    }
end

--- Run all pending effects after render.
---@param ctx HookContext
function M.run_effects(ctx)
    for _, effect in ipairs(ctx.effects) do
        if effect.pending then
            if effect.cleanup then
                pcall(effect.cleanup)
            end
            local cleanup = effect.fn()
            effect.cleanup = type(cleanup) == 'function' and cleanup or nil
            effect.pending = false
        end
    end
end

--- Clean up all effects.
---@param ctx HookContext
function M.cleanup(ctx)
    for _, effect in ipairs(ctx.effects) do
        if effect.cleanup then
            pcall(effect.cleanup)
            effect.cleanup = nil
        end
    end
    -- Also clean up useLayoutEffect hooks
    for _, hook in ipairs(ctx.hooks) do
        if type(hook) == 'table' and hook.cleanup then
            pcall(hook.cleanup)
            hook.cleanup = nil
        end
    end
end

-- ── Hooks ──────────────────────────────────────────────────────

--- useState: reactive state that triggers re-render on change.
---@param initial any
---@return any value, fun(new: any) setter
function M.useState(initial)
    assert(_current_ctx, 'useState must be called inside a component render')
    _hook_index = _hook_index + 1
    local idx = _hook_index
    local ctx = _current_ctx

    if ctx.hooks[idx] == nil then
        ctx.hooks[idx] = { value = initial }
    end

    local hook = ctx.hooks[idx]
    local setter = function(new_value)
        if type(new_value) == 'function' then
            new_value = new_value(hook.value)
        end
        if hook.value ~= new_value then
            hook.value = new_value
            ctx.dirty = true
            if _batching then
                _batch_queue[ctx] = ctx.on_dirty
            elseif ctx.on_dirty then
                vim.schedule(ctx.on_dirty)
            end
        end
    end

    return hook.value, setter
end

--- useMemo: memoized computation, recomputed when deps change.
---@param fn function
---@param deps any[]
---@return any
function M.useMemo(fn, deps)
    assert(_current_ctx, 'useMemo must be called inside a component render')
    _hook_index = _hook_index + 1
    local idx = _hook_index
    local ctx = _current_ctx

    if ctx.hooks[idx] == nil then
        ctx.hooks[idx] = { value = nil, deps = nil }
    end

    local hook = ctx.hooks[idx]
    local deps_changed = hook.deps == nil or not M._deps_equal(hook.deps, deps)

    if deps_changed then
        hook.value = fn()
        hook.deps = deps
    end

    return hook.value
end

--- useCallback: stable function reference, recreated when deps change.
---@param fn function
---@param deps any[]
---@return function
function M.useCallback(fn, deps)
    return M.useMemo(function() return fn end, deps)
end

--- useEffect: side effect that runs after render, with optional cleanup.
---@param fn fun(): fun()|nil # effect function, may return cleanup
---@param deps any[]|nil # dependency array (nil = run every render)
function M.useEffect(fn, deps)
    assert(_current_ctx, 'useEffect must be called inside a component render')
    _hook_index = _hook_index + 1
    local idx = _hook_index
    local ctx = _current_ctx

    if ctx.hooks[idx] == nil then
        ctx.hooks[idx] = { deps = nil }
        ctx.effects[#ctx.effects + 1] = { fn = fn, deps = deps, pending = true, hook_idx = idx }
    else
        local hook = ctx.hooks[idx]
        local should_run = deps == nil or not M._deps_equal(hook.deps, deps)
        hook.deps = deps

        for _, effect in ipairs(ctx.effects) do
            if effect.hook_idx == idx then
                effect.fn = fn
                effect.pending = should_run
                break
            end
        end
    end
end

--- useRef: mutable ref that persists across renders without triggering re-render.
---@param initial any
---@return { current: any }
function M.useRef(initial)
    assert(_current_ctx, 'useRef must be called inside a component render')
    _hook_index = _hook_index + 1
    local idx = _hook_index
    local ctx = _current_ctx

    if ctx.hooks[idx] == nil then
        ctx.hooks[idx] = { current = initial }
    end

    return ctx.hooks[idx]
end

--- useReducer: complex state management via a reducer function.
--- Like React's useReducer: (state, action) => newState.
---@param reducer fun(state: any, action: any): any
---@param initial_state any
---@return any state, fun(action: any) dispatch
function M.useReducer(reducer, initial_state)
    assert(_current_ctx, 'useReducer must be called inside a component render')
    _hook_index = _hook_index + 1
    local idx = _hook_index
    local ctx = _current_ctx

    if ctx.hooks[idx] == nil then
        ctx.hooks[idx] = { value = initial_state }
    end

    local hook = ctx.hooks[idx]
    local dispatch = function(action)
        local new_state = reducer(hook.value, action)
        if hook.value ~= new_state then
            hook.value = new_state
            ctx.dirty = true
            if _batching then
                _batch_queue[ctx] = ctx.on_dirty
            elseif ctx.on_dirty then
                vim.schedule(ctx.on_dirty)
            end
        end
    end

    return hook.value, dispatch
end

--- Context: shared state across a component tree.
---@class ReactContext
---@field _value any
---@field _subscribers function[]

--- createContext: create a context object for shared state.
---@param default_value any
---@return ReactContext
function M.createContext(default_value)
    return {
        _value = default_value,
        _subscribers = {},
        Provider = function(self, value)
            self._value = value
            for _, sub in ipairs(self._subscribers) do
                pcall(sub, value)
            end
        end,
    }
end

--- useContext: read a context value reactively.
--- Re-renders the component when the context value changes.
---@param context ReactContext
---@return any
function M.useContext(context)
    assert(_current_ctx, 'useContext must be called inside a component render')
    local value, setValue = M.useState(context._value)
    M.useEffect(function()
        local function on_change(new_val) setValue(new_val) end
        context._subscribers[#context._subscribers + 1] = on_change
        return function()
            for i, sub in ipairs(context._subscribers) do
                if sub == on_change then
                    table.remove(context._subscribers, i)
                    break
                end
            end
        end
    end, { context })
    return value
end

--- useLayoutEffect: like useEffect but runs synchronously after render.
--- Use for DOM measurements or synchronous side effects.
---@param fn fun(): fun()|nil
---@param deps any[]|nil
function M.useLayoutEffect(fn, deps)
    assert(_current_ctx, 'useLayoutEffect must be called inside a component render')
    _hook_index = _hook_index + 1
    local idx = _hook_index
    local ctx = _current_ctx

    if ctx.hooks[idx] == nil then
        ctx.hooks[idx] = { deps = nil, cleanup = nil }
    end

    local hook = ctx.hooks[idx]
    local should_run = deps == nil or not M._deps_equal(hook.deps, deps)
    hook.deps = deps

    if should_run then
        if hook.cleanup then pcall(hook.cleanup) end
        local cleanup = fn()
        hook.cleanup = type(cleanup) == 'function' and cleanup or nil
    end
end

--- batch: group multiple state updates into a single re-render.
--- All setState/dispatch calls inside fn() are deferred. Re-render fires once after fn() returns.
---@param fn function
function M.batch(fn)
    _batching = true
    _batch_queue = {}
    pcall(fn)
    _batching = false
    for _, on_dirty in pairs(_batch_queue) do
        if on_dirty then vim.schedule(on_dirty) end
    end
    _batch_queue = {}
end

-- ── IDE-specific hooks ────────────────────────────────────────

--- useKeymap: declarative keymap that is set on mount and removed on unmount.
--- Automatically re-registers when mode, lhs, or rhs changes.
---@param mode string|string[]
---@param lhs string
---@param rhs string|function
---@param opts { desc?: string, buffer?: integer, expr?: boolean }|nil
function M.useKeymap(mode, lhs, rhs, opts)
    opts = opts or {}
    M.useEffect(function()
        if IDE and IDE.keys then
            IDE.keys:map(mode, lhs, rhs, opts)
        end
        return function()
            local modes = type(mode) == 'table' and mode or { mode }
            for _, m in ipairs(modes) do
                pcall(vim.keymap.del, m, lhs, opts.buffer and { buffer = opts.buffer } or {})
            end
        end
    end, { mode, lhs, opts.buffer })
end

--- useAutoCmd: declarative autocmd that is created on mount and removed on unmount.
---@param events string|string[]
---@param callback function
---@param opts { pattern?: string|string[], buffer?: integer, desc?: string }|nil
function M.useAutoCmd(events, callback, opts)
    opts = opts or {}
    M.useEffect(function()
        local id = vim.api.nvim_create_autocmd(events, {
            pattern = opts.pattern,
            buffer = opts.buffer,
            callback = callback,
            desc = opts.desc,
        })
        return function()
            pcall(vim.api.nvim_del_autocmd, id)
        end
    end, { events, opts.pattern, opts.buffer })
end

--- useToggle: subscribe to a config toggle value reactively.
--- Returns the current value and a setter function.
---@param name string
---@return boolean value, fun(enabled: boolean) setter
function M.useToggle(name)
    local enabled, setEnabled = M.useState(
        IDE and IDE.config and IDE.config:is_enabled(name) or false
    )
    M.useEffect(function()
        if not IDE or not IDE.config then return end
        local unsub = IDE.config:on('toggle', function(toggle_name, value)
            if toggle_name == name then
                setEnabled(value)
            end
        end)
        return unsub
    end, { name })
    local setter = M.useCallback(function(value)
        if IDE and IDE.config then
            IDE.config:set_toggle(name, value)
        end
    end, { name })
    return enabled, setter
end

--- useBuffer: get the current buffer reactively (updates on BufEnter).
---@return table|nil # Buffer instance
function M.useBuffer()
    local Buffer = require 'ide.Buffer'
    local buf, setBuf = M.useState(Buffer.current())
    M.useAutoCmd('BufEnter', function()
        setBuf(Buffer.current())
    end)
    return buf
end

--- useLsp: get LSP clients for the current buffer reactively.
---@return table[] # array of LSP client objects
function M.useLsp()
    local buf = M.useBuffer()
    local clients, setClients = M.useState({})
    M.useAutoCmd({ 'LspAttach', 'LspDetach' }, function()
        if buf and buf:is_valid() then
            setClients(buf:lsp():clients())
        end
    end)
    return clients
end

--- useDebouncedEffect: like useEffect but debounces — only fires after
--- the deps stabilize for `delay` ms. Useful for expensive operations
--- triggered by rapidly-changing state (search input, cursor movement).
---@param fn function
---@param deps any[]
---@param delay integer # debounce delay in milliseconds
function M.useDebouncedEffect(fn, deps, delay)
    local timer_ref = M.useRef(nil)
    M.useEffect(function()
        if timer_ref.current then
            timer_ref.current:stop()
        end
        local Timer = require 'ide.Timer'
        timer_ref.current = Timer.delay(delay, function()
            fn()
        end)
        return function()
            if timer_ref.current then
                timer_ref.current:stop()
                timer_ref.current = nil
            end
        end
    end, deps)
end

--- useDebouncedState: like useState but the setter debounces updates.
--- The value updates immediately in the component, but effects/renders
--- are batched to avoid excessive re-renders.
---@param initial any
---@param delay integer # debounce delay in ms
---@return any value, fun(new: any) setter
function M.useDebouncedState(initial, delay)
    local value, setValue = M.useState(initial)
    local timer_ref = M.useRef(nil)
    local setter = function(new_value)
        if timer_ref.current then timer_ref.current:stop() end
        local Timer = require 'ide.Timer'
        timer_ref.current = Timer.delay(delay, function()
            setValue(new_value)
        end)
    end
    return value, setter
end

-- ── Internal ───────────────────────────────────────────────────

--- Compare two dependency arrays for equality.
---@param a any[]
---@param b any[]
---@return boolean
function M._deps_equal(a, b)
    if a == nil or b == nil then return false end
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return true
end

return M
