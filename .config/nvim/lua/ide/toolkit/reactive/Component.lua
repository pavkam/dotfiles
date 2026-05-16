-- Component: base class for reactive UI components.
-- Inspired by React class components. Components have:
--   - Immutable props (passed by parent)
--   - Mutable state (managed internally via setState)
--   - render() returning a description of what to display
--   - Lifecycle hooks (didMount, willUnmount, didUpdate)
--   - Batched re-renders via vim.schedule

local EventEmitter = require 'ide.EventEmitter'

local Component = Class('Component')
Class.include(Component, EventEmitter)

--- Render batch queue. Multiple setState calls coalesce into one re-render.
local _render_queue = {}
local _render_scheduled = false

local function flush_render_queue()
    _render_scheduled = false
    local queue = _render_queue
    _render_queue = {}
    for _, comp in ipairs(queue) do
        if comp._mounted and comp._dirty then
            comp._dirty = false
            local prev_state = comp._prev_state
            local prev_props = comp._prev_props
            comp._prev_state = nil
            comp._prev_props = nil
            comp:_do_render()
            if comp.componentDidUpdate then
                comp:componentDidUpdate(prev_props or comp.props, prev_state or comp.state)
            end
        end
    end
end

local function schedule_render(comp)
    if not comp._dirty then
        comp._dirty = true
        _render_queue[#_render_queue + 1] = comp
    end
    if not _render_scheduled then
        _render_scheduled = true
        vim.schedule(flush_render_queue)
    end
end

---@param props table|nil
function Component:init(props)
    self.props = props or {}
    self.state = {}
    self._mounted = false
    self._dirty = false
    self._prev_state = nil
    self._prev_props = nil
    self._parent = nil  ---@type Component|nil
    self._children = {} ---@type Component[]
    self._render_result = nil
end

--- Merge partial state and schedule a re-render.
--- Multiple calls within the same synchronous block are batched.
---@param updates table
function Component:setState(updates)
    if not self._mounted then return end

    -- Save previous state for componentDidUpdate
    if not self._prev_state then
        self._prev_state = vim.tbl_deep_extend('force', {}, self.state)
    end

    -- Merge updates into state
    for k, v in pairs(updates) do
        self.state[k] = v
    end

    -- Check optimization gate
    if self.shouldComponentUpdate then
        if not self:shouldComponentUpdate(self.props, self.state) then
            self._prev_state = nil
            return
        end
    end

    schedule_render(self)
end

--- Force a re-render, bypassing shouldComponentUpdate.
function Component:forceUpdate()
    if not self._mounted then return end
    self._prev_state = vim.tbl_deep_extend('force', {}, self.state)
    schedule_render(self)
end

--- Abstract: return a description of what to render.
--- Subclasses MUST override this.
---@return table|string|nil # VNode tree, string, or nil
function Component:render()
    return nil
end

--- Called after the component is first rendered and mounted.
function Component:componentDidMount() end

--- Called before the component is unmounted and destroyed.
function Component:componentWillUnmount() end

--- Called after a re-render. Receives previous props and state.
---@param prevProps table
---@param prevState table
function Component:componentDidUpdate(prevProps, prevState) end

--- Optimization gate: return false to skip re-render.
--- Default: always re-render.
---@param nextProps table
---@param nextState table
---@return boolean
function Component:shouldComponentUpdate(nextProps, nextState)
    return true
end

--- Mount this component (called by the renderer).
function Component:_mount()
    self._mounted = true
    self:_do_render()
    self:componentDidMount()
    self:emit('mount')
end

--- Unmount this component (called by the renderer).
function Component:_unmount()
    self:componentWillUnmount()
    self._mounted = false
    self:emit('unmount')
    -- Unmount children
    for _, child in ipairs(self._children) do
        if child._mounted then child:_unmount() end
    end
    self._children = {}
end

--- Internal: execute the render method and store the result.
function Component:_do_render()
    self._render_result = self:render()
end

--- Update props from parent and trigger re-render if changed.
---@param new_props table
function Component:_update_props(new_props)
    if not self._mounted then return end
    self._prev_props = self.props
    self.props = new_props

    if self.shouldComponentUpdate then
        if not self:shouldComponentUpdate(new_props, self.state) then
            self._prev_props = nil
            return
        end
    end

    schedule_render(self)
end

--- Check if the component is currently mounted.
---@return boolean
function Component:is_mounted()
    return self._mounted
end

--- Dispatch an event upward through the component tree.
---@param event string
---@param ... any
function Component:dispatchEvent(event, ...)
    self:emit(event, ...)
    if self._parent then
        self._parent:dispatchEvent(event, ...)
    end
end

---@return string
function Component:__tostring()
    return string.format('Component(%s, %s)',
        self.__class and self.__class.__name or '?',
        self._mounted and 'mounted' or 'unmounted')
end

--- Get the render queue size (for testing/diagnostics).
---@return integer
function Component._queue_size()
    return #_render_queue
end

return Component
