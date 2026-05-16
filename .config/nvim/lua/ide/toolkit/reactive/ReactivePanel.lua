-- ReactivePanel: a Panel that hosts a reactive Component.
-- Mounts the component, renders its VNode tree to a Canvas,
-- and re-renders when state changes.

local Panel = require 'ide.toolkit.Panel'
local Renderer = require 'ide.toolkit.reactive.Renderer'

local ReactivePanel = Class('ReactivePanel', Panel)

---@param component table # Component instance
---@param opts { title?: string, width?: number, height?: number, position?: string }|nil
function ReactivePanel:init(component, opts)
    opts = opts or {}
    Panel.init(self, {
        title = opts.title or '',
        width = opts.width or 0.5,
        height = opts.height or 0.4,
        enter = opts.enter ~= false,
        position = opts.position or 'center',
    })
    self._component = component
end

function ReactivePanel:_on_mount()
    -- Mount the component
    self._component:_mount()

    -- Listen for state changes to re-render
    self._component:on('_state_changed', function()
        self:_render_component()
    end)

    -- Initial render
    self:_render_component()
end

function ReactivePanel:_render_component()
    local buf = self:buffer()
    if not buf or not buf:is_valid() then return end

    local w, h = self:size()
    if w <= 0 or h <= 0 then return end

    -- Re-run render to get fresh VNode tree
    self._component:_do_render()

    -- Layout and paint
    local canvas = Renderer.render_component(self._component, {
        row = 1, col = 1, width = w, height = h,
    })

    canvas:render(buf)
end

function ReactivePanel:hide()
    if self._component and self._component:is_mounted() then
        self._component:_unmount()
    end
    Panel.hide(self)
end

---@return string
function ReactivePanel:__tostring()
    return string.format('ReactivePanel(%s)', tostring(self._component))
end

return ReactivePanel
